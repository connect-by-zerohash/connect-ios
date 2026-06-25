import assert from "node:assert";
import { test } from "node:test";
import { foldMultipart, parseConnection } from "./shim.mjs";

test("foldMultipart merges @defer incremental chunks", () => {
  const text =
    '--graphql\r\ncontent-type: application/json\r\n\r\n' +
    '{"data":{"viewer":{"cryptoAssets":{"edges":[]}}},"hasNext":true}\r\n' +
    '--graphql\r\ncontent-type: application/json\r\n\r\n' +
    '{"incremental":[{"path":["viewer","cryptoAssets"],"data":{"edges":[{"node":{"asset":{"asset":{"displaySymbol":"BTC","name":"Bitcoin"}},"totalBalanceCrypto":{"amount":"0.5"},"totalBalanceFiat":{"amount":"30000"}}}]}}],"hasNext":false}\r\n' +
    '--graphql--\r\n';
  const folded = foldMultipart(text);
  assert.equal(folded.data.viewer.cryptoAssets.edges.length, 1);
  assert.equal(folded.hasNext, undefined);
});

test("parseConnection extracts a crypto balance and skips zero rows", () => {
  const folded = { data: { viewer: {
    oneDayCryptoPerformance: { returns: { unrealized: { value: { currency: "USD" } } } },
    cryptoAssets: { edges: [
      { node: { asset: { asset: { displaySymbol: "BTC", name: "Bitcoin" } }, totalBalanceCrypto: { amount: "0.5" }, totalBalanceFiat: { amount: "30000" } } },
      { node: { asset: { asset: { displaySymbol: "ETH", name: "Ethereum" } }, totalBalanceCrypto: { amount: "0" }, totalBalanceFiat: { amount: "0" } } }
    ] }
  } } };
  const r = parseConnection(folded, "cryptoAssets", "CryptoQuery");
  assert.equal(r.status, "complete");
  assert.equal(r.balances.length, 1);
  assert.equal(r.balances[0].key, "BTC");
  assert.equal(r.balances[0].currency, "USD");
});

test("parseConnection returns incomplete when viewer is missing", () => {
  const r = parseConnection({ data: {} }, "cryptoAssets", "CryptoQuery");
  assert.equal(r.status, "incomplete");
});

test("parseConnection treats empty edges as authoritative zero (complete)", () => {
  const folded = { data: { viewer: { cryptoAssets: { edges: [] } } } };
  const r = parseConnection(folded, "cryptoAssets", "CryptoQuery");
  assert.equal(r.status, "complete");
  assert.equal(r.balances.length, 0);
});
