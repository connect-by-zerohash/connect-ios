// Strategy A (captcha reduction): a single page load must replay BOTH balance
// ops (CryptoQuery + CashQuery) and concatenate the results, instead of one
// navigation per op. This test drives that behaviour by stubbing `fetch` so the
// pure replay/fold/parse path runs in Node — no network, no WebView.
import assert from "node:assert";
import { test } from "node:test";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

const src = readFileSync(fileURLToPath(new URL("../../../Sources/ConnectSDK/Platforms/Coinbase/get-balance.js", import.meta.url)), "utf8");

// Load get-balance.js in a fresh realm with the host globals `replay` needs.
// ECMAScript intrinsics (JSON, Date, encodeURIComponent, Promise, …) come free;
// fetch / AbortController / timers are host-provided so we inject them.
function loadRun(fetchImpl) {
  const module = { exports: {} };
  const ctx = {
    module,
    console,
    fetch: fetchImpl,
    AbortController: class { constructor() { this.signal = {}; } abort() {} },
    setTimeout: () => 0,
    clearTimeout: () => {},
  };
  vm.runInNewContext(src, ctx);
  return module.exports.run;
}

function jsonResponse(bodyObj) {
  const text = JSON.stringify(bodyObj);
  return {
    status: 200,
    headers: { get: (h) => (h === "content-type" ? "application/json" : null) },
    text: async () => text,
  };
}

const QUERIES = {
  CryptoQuery: { operationName: "CryptoQuery", sha256Hash: "h1", query: null, variables: {}, field: "cryptoAssets" },
  CashQuery:   { operationName: "CashQuery",   sha256Hash: "h2", query: null, variables: {}, field: "cashAssets" },
};

const BODIES = {
  CryptoQuery: { data: { viewer: {
    oneDayCryptoPerformance: { returns: { unrealized: { value: { currency: "USD" } } } },
    cryptoAssets: { edges: [
      { node: { asset: { asset: { displaySymbol: "BTC", name: "Bitcoin" } }, totalBalanceCrypto: { amount: "0.5" }, totalBalanceFiat: { amount: "30000" } } },
    ] },
  } } },
  CashQuery: { data: { viewer: {
    cashAssets: { edges: [
      { node: { asset: { asset: { displaySymbol: "USDC", name: "USDC" } }, totalBalanceCrypto: { amount: "2.0" }, totalBalanceFiat: { amount: "2.0" } } },
    ] },
  } } },
};

test("run replays both ops in one page and concatenates balances in order", async () => {
  const calls = [];
  const run = loadRun(async (url) => {
    const op = decodeURIComponent(/operationName=([^&]+)/.exec(url)[1]);
    calls.push(op);
    return jsonResponse(BODIES[op]);
  });

  // QUERIES carry no nativeCurrency, so this exercises the fallback path:
  // crypto reports its own currency, cash has none.
  const result = await run({ ops: ["CryptoQuery", "CashQuery"], waitForChallenge: false }, QUERIES);

  // One page, two replays (no per-op navigation).
  assert.deepEqual(calls, ["CryptoQuery", "CashQuery"]);
  assert.equal(result.balances.length, 2);
  assert.equal(result.balances[0].key, "BTC");
  assert.equal(result.balances[0].currency, "USD"); // fallback: crypto's reported currency
  assert.equal(result.balances[1].key, "USDC");
  assert.equal(result.balances[1].currency, null);  // fallback: cash has no reported currency
});

test("run labels EVERY row with the requested account currency (nativeCurrency)", async () => {
  const run = loadRun(async (url) => {
    const op = decodeURIComponent(/operationName=([^&]+)/.exec(url)[1]);
    return jsonResponse(BODIES[op]);
  });

  // The whole account is denominated in one fiat. Request EUR to prove the
  // currency is sourced from nativeCurrency and applied to ALL rows — including
  // cash (no longer null) and overriding crypto's own reported "USD".
  const queries = {
    CryptoQuery: { ...QUERIES.CryptoQuery, variables: { nativeCurrency: "EUR" } },
    CashQuery:   { ...QUERIES.CashQuery,   variables: { nativeCurrency: "EUR" } },
  };

  const result = await run({ ops: ["CryptoQuery", "CashQuery"], waitForChallenge: false }, queries);

  assert.equal(result.balances[0].key, "BTC");
  assert.equal(result.balances[0].currency, "EUR"); // overrides reported USD
  assert.equal(result.balances[1].key, "USDC");
  assert.equal(result.balances[1].currency, "EUR"); // cash inherits account currency
});
