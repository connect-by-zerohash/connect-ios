import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

const src = readFileSync(fileURLToPath(new URL("../../../Sources/ConnectSDK/Platforms/Coinbase/get-balance.js", import.meta.url)), "utf8");
const module = { exports: {} };
vm.runInNewContext(src, { module, console });
export const { foldMultipart, parseConnection, deepMerge, run } = module.exports;
