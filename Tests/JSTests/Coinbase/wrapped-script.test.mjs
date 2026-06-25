// Regression guard for two things:
//  1. (C1 bug) get-balance.js is injected by the Swift runner inside a
//     `return ( … )` slot (AutomatedWebViewController.evaluateAsync), after
//     Coinbase.getBalance wraps it as
//       (function(){ <queries>; return (<file>); })()
//     The file therefore MUST be a single expression. If someone reintroduces
//     top-level statements, this test fails before it ever reaches a device.
//  2. (CWE-94) request data (`params`) must NOT be interpolated into the script
//     source — it is delivered as a bound `callAsyncJavaScript` argument, so the
//     built source must contain no params literal.
import assert from "node:assert";
import { test } from "node:test";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const dir = fileURLToPath(new URL(".", import.meta.url));
const srcDir = dir + "../../../Sources/ConnectSDK/Platforms/Coinbase/";
const balance = readFileSync(srcDir + "get-balance.js", "utf8");
const queries = readFileSync(srcDir + "coinbase-balance-queries.js", "utf8");

function buildInjectedScript() {
  // Mirror Coinbase.getBalance's string building (strip trailing ;/space/newline).
  // NOTE: params are NOT interpolated — they arrive as a bound argument.
  const automation = balance.replace(/[;\s]+$/, "");
  return "(function(){ " + queries + "; return (" + automation + "); })()";
}

test("injected script parses (single-expression file, params bound not interpolated)", () => {
  const inner = buildInjectedScript();
  // The runner adds an outer `return ( … );` wrap and binds `params` as a
  // function argument (callAsyncJavaScript arguments: ["params": …]).
  assert.doesNotThrow(() => new Function("params", "return (\n" + inner + "\n);"));
});

test("injected source carries no interpolated params (CWE-94)", () => {
  const inner = buildInjectedScript();
  assert.ok(!inner.includes("window.__zhBalanceParams"));
});
