import {readFileSync} from 'node:fs'
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const mvmJson = JSON.parse(readFileSync(join(__dirname, './mvm.json'), 'utf-8'))
const version = process.version
if (version !== mvmJson.node) {
    throw new Error(`Node版本不匹配，期望版本 ${mvmJson.node}，实际版本 ${version}`)
}
