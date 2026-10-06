import { createRequire as __bookipiCreateRequire } from 'node:module';
const require = __bookipiCreateRequire(import.meta.url);
import {
  require_execAsync
} from "./chunk-5U2H6RRI.js";
import {
  esm_exports,
  init_esm
} from "./chunk-PUH7ZX2U.js";
import {
  __commonJS,
  __require,
  __toCommonJS
} from "./chunk-5VM4XHTU.js";

// node_modules/.pnpm/@opentelemetry+resources@2.11.0_@opentelemetry+api@1.9.1/node_modules/@opentelemetry/resources/build/src/detectors/platform/node/machine-id/getMachineId-win.js
var require_getMachineId_win = __commonJS({
  "node_modules/.pnpm/@opentelemetry+resources@2.11.0_@opentelemetry+api@1.9.1/node_modules/@opentelemetry/resources/build/src/detectors/platform/node/machine-id/getMachineId-win.js"(exports) {
    Object.defineProperty(exports, "__esModule", { value: true });
    exports.getMachineId = void 0;
    var process = __require("process");
    var execAsync_1 = require_execAsync();
    var api_1 = (init_esm(), __toCommonJS(esm_exports));
    async function getMachineId() {
      const args = "QUERY HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Cryptography /v MachineGuid";
      let command = "%windir%\\System32\\REG.exe";
      if (process.arch === "ia32" && "PROCESSOR_ARCHITEW6432" in process.env) {
        command = "%windir%\\sysnative\\cmd.exe /c " + command;
      }
      try {
        const result = await (0, execAsync_1.execAsync)(`${command} ${args}`);
        const parts = result.stdout.split("REG_SZ");
        if (parts.length === 2) {
          return parts[1].trim();
        }
      } catch (e) {
        api_1.diag.debug(`error reading machine id: ${e}`);
      }
      return void 0;
    }
    exports.getMachineId = getMachineId;
  }
});
export default require_getMachineId_win();
