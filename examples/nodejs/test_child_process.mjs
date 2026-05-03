/**
 * 检查子进程中的node版本是否正确
 */

import { execSync } from "node:child_process";
import { checkVersion, join_path } from "./nodejs.mjs";
import { dirname } from "node:path";

let result = execSync("node -v", { encoding: "utf-8" }).trim();
checkVersion(result);

const mvmJsonPath = join_path("../../mvm.json");
const cwd = dirname(mvmJsonPath);
result = execSync("node -v", {
    encoding: "utf-8",
    cwd,
}).trim();
checkVersion(result, mvmJsonPath);
