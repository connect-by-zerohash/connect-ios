// `totalStakedPercent` is the non-withdrawable slice of a row: consumers compute
// `withdrawable = amount * (1 - totalStakedPercent / 100)`. Getting it wrong
// either hides funds the user can spend or offers funds the exchange will refuse
// to send, so each rule it has to obey is pinned down here.
//
// The contract is `string | null` — a decimal percent, never a percent sign and
// never a non-numeric string. See scraper-browser-extensions
// docs/contracts/operations/get-balance.md.
import assert from "node:assert";
import { test } from "node:test";
import { parseConnection } from "./shim.mjs";

// Fixtures carry only the fields the parser reads. Coinbase's real response is
// ~300 fields per row; pasting one in would bury what each test pins down.

/**
 * `staked` is Coinbase's raw `staking.summary.totalStakedPercent` — a decimal in
 * 0–1, NOT a percent. Omit it for an asset that cannot be staked; the `staking`
 * branch is then absent exactly as it is in the live response.
 */
function cryptoRow({ symbol, name, amount, notional, staked }) {
  const asset = { asset: { displaySymbol: symbol, name } };
  if (staked !== undefined) asset.staking = { summary: { totalStakedPercent: staked } };
  const folded = {
    data: {
      viewer: {
        cryptoAssets: {
          edges: [
            {
              node: {
                totalBalanceCrypto: { amount },
                totalBalanceFiat: { amount: notional },
                asset
              }
            }
          ]
        }
      }
    }
  };
  return parseConnection(folded, "cryptoAssets", "CryptoQuery", "USD").balances[0];
}

/**
 * `accounts` is the per-account breakdown Coinbase returns under the ViewerAsset:
 * a lent (DeFi Lend) slice shows up as an extra account with
 * `allowWithdrawals: false`, and its balance is NOT deducted from the sibling
 * account, so the locked share has to be derived from the split.
 */
function cashRow({ symbol, name, amount, notional, accounts }) {
  const folded = {
    data: {
      viewer: {
        cashAssets: {
          edges: [
            {
              node: {
                totalBalanceCrypto: { amount },
                totalBalanceFiat: { amount: notional },
                asset: {
                  asset: { displaySymbol: symbol, name },
                  ...(accounts === undefined ? {} : { accounts })
                }
              }
            }
          ]
        }
      }
    }
  };
  return parseConnection(folded, "cashAssets", "CashQuery", "USD").balances[0];
}

/** A wallet account: spendable, withdrawable. */
const wallet = (native) => ({
  type: "WALLET",
  allowWithdrawals: true,
  totalBalanceInNativeCurrency: { value: native }
});

/** A DeFi Lend account: lent out, so locked. */
const lent = (native) => ({
  type: "RETAIL_DEFI_LEND",
  allowWithdrawals: false,
  totalBalanceInNativeCurrency: { value: native }
});

// ─── crypto: staking ─────────────────────────────────────────────────────────

test("a staked crypto asset scales Coinbase's 0-1 fraction to a percent", () => {
  const row = cryptoRow({
    symbol: "ETH", name: "Ethereum", amount: "10", notional: "25000", staked: "0.5"
  });
  assert.strictEqual(row.totalStakedPercent, "50");
});

test("a crypto asset that cannot be staked reports null", () => {
  const row = cryptoRow({
    symbol: "BTC", name: "Bitcoin", amount: "0.5321", notional: "34120.55"
  });
  assert.strictEqual(row.totalStakedPercent, null);
});

test("a fully staked crypto asset reports 100", () => {
  const row = cryptoRow({
    symbol: "ETH", name: "Ethereum", amount: "10", notional: "25000", staked: "1"
  });
  assert.strictEqual(row.totalStakedPercent, "100");
});

// A blank or junk value used to reach the consumer as the string "NaN", which is
// neither a number nor null: `parseFloat("NaN")` is NaN downstream, and a strict
// schema rejects the row outright. Absent data must read as absent.
test("a non-numeric staking percent reports null, not the string NaN", () => {
  for (const staked of ["", "abc", "null"]) {
    const row = cryptoRow({
      symbol: "SOL", name: "Solana", amount: "5", notional: "900", staked
    });
    assert.strictEqual(
      row.totalStakedPercent, null,
      `raw ${JSON.stringify(staked)} must not survive into the row`
    );
  }
});

// ─── cash: DeFi Lend ─────────────────────────────────────────────────────────

// Cash has no staking, but a cash asset CAN be lent out via DeFi Lend. Lent funds
// are not withdrawable, and Coinbase does not reduce the sibling account's
// balance — the only signal is the per-account `allowWithdrawals` split. Reported
// through the same field because consumers already treat it as the
// non-withdrawable slice.
test("a cash asset lent via DeFi Lend reports the locked fraction", () => {
  const row = cashRow({
    symbol: "USDC", name: "USD Coin", amount: "1000", notional: "1000",
    accounts: [wallet("600"), lent("400")]
  });
  assert.strictEqual(row.totalStakedPercent, "40");
});

test("a fully lent cash asset reports 100", () => {
  const row = cashRow({
    symbol: "USDC", name: "USD Coin", amount: "1000", notional: "1000",
    accounts: [lent("1000")]
  });
  assert.strictEqual(row.totalStakedPercent, "100");
});

test("a cash asset with nothing lent reports null", () => {
  const row = cashRow({
    symbol: "USDC", name: "USD Coin", amount: "1000", notional: "1000",
    accounts: [wallet("1000")]
  });
  assert.strictEqual(row.totalStakedPercent, null);
});

// Absent breakdown is not "nothing is locked" with confidence, but it is the only
// answer available, and null is how the field says "no locked slice known".
test("a cash asset with no account breakdown reports null", () => {
  const row = cashRow({
    symbol: "USDC", name: "USD Coin", amount: "1000", notional: "1000"
  });
  assert.strictEqual(row.totalStakedPercent, null);
});

// An account whose native balance is missing or junk must not poison the ratio:
// counting it as 0 in the total would overstate the locked share.
test("an account with an unusable balance is left out of the ratio", () => {
  const row = cashRow({
    symbol: "USDC", name: "USD Coin", amount: "1000", notional: "1000",
    accounts: [
      wallet("500"),
      lent("500"),
      { type: "WALLET", allowWithdrawals: true, totalBalanceInNativeCurrency: { value: "abc" } }
    ]
  });
  assert.strictEqual(row.totalStakedPercent, "50");
});

// ─── the rest of the row must not shift ──────────────────────────────────────

test("the staking fields do not disturb the rest of the row", () => {
  const row = cryptoRow({
    symbol: "ETH", name: "Ethereum", amount: "10", notional: "25000", staked: "0.5"
  });
  assert.strictEqual(row.key, "ETH");
  assert.strictEqual(row.label, "Ethereum");
  assert.strictEqual(row.amount, "10");
  assert.strictEqual(row.notional, "25000");
  assert.strictEqual(row.currency, "USD");
  assert.strictEqual(row.precision, null);
  assert.match(row.extractedAt, /^\d{4}-\d{2}-\d{2}T[\d:.]+Z$/);
});
