import { readFileSync } from "node:fs";
import { dirname, join, isAbsolute } from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const mvmJson = JSON.parse(
    readFileSync(join(__dirname, "./mvm.json"), "utf-8"),
);

export function join_path(...paths) {
    return join(__dirname, ...paths);
}

export function checkVersion(actual, mvmJsonFilePath = "./mvm.json") {
    mvmJsonFilePath = isAbsolute(mvmJsonFilePath)
        ? mvmJsonFilePath
        : join(__dirname, mvmJsonFilePath);
    const mvmJson = JSON.parse(readFileSync(mvmJsonFilePath, "utf-8"));
    if (actual !== mvmJson.node) {
        throw new Error(
            `Node版本不匹配，期望版本 ${mvmJson.node}，实际版本 ${version}`,
        );
    }
}
