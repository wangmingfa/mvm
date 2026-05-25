<div align="center">

```
███╗   ███╗██╗   ██╗███╗   ███╗
████╗ ████║██║   ██║████╗ ████║
██╔████╔██║██║   ██║██╔████╔██║
██║╚██╔╝██║╚██╗ ██╔╝██║╚██╔╝██║
██║ ╚═╝ ██║ ╚████╔╝ ██║ ╚═╝ ██║
╚═╝     ╚═╝  ╚═══╝  ╚═╝     ╚═╝
```

# wangmingfa/mvm

**🌐 [English](README_en.md) | 中文**

mvm（Multi Version Manager）——One Tool to Manage Them All

</div>

再也不用为不同语言安装不同的版本管理器而头疼了。

mvm 是一款现代化的多语言版本管理工具，支持 Node.js、Bun、Zig、Go、Python、Rust、Deno、Java、Kotlin 以及更多语言。只需一条命令，你就可以在项目之间自由切换任意语言的版本，干净、高效、毫不妥协。

简单、统一、极快 —— 这就是 mvm。

> 💡 此工具灵感来源于 [Volta](https://volta.sh/)。

## 安装

**macOS / Linux**
```bash
curl -fsSL https://raw.githubusercontent.com/wangmingfa/mvm/main/scripts/install_online.sh | bash
```

**Windows（PowerShell）**

```powershell
powershell -c "irm https://raw.githubusercontent.com/wangmingfa/mvm/main/scripts/install_online.ps1|iex"
```

> **提示：** 如果脚本执行时遇到中文乱码导致报错，请按照 [此文档](https://wangmingfa.github.io/docs/#/windows/powershell/garbled-text) 进行操作。

## 平台支持

- macOS：ARM 架构（Apple Silicon）
- Windows：x86 架构
- Linux：x86 架构

## 支持的工具

mvm 支持 9 种开发工具，每种工具均可使用全部版本管理命令（install、use、pin、unuse、uninstall、list、current、which、run）。

| 命令名 | 工具 | 可执行命令 | 命令测试覆盖 |
|--------|------|-----------|-------------|
| node | Node.js | node, npm, npx, corepack, npm 全局包 | ★★★★★ |
| bun | Bun | bun, bunx | ★ |
| zig | Zig | zig | ★ |
| go | Go | go, gofmt | ★ |
| python / python3 | Python | python3, python | ★ |
| rust / rustc | Rust | rustc, cargo, rustfmt, cargo-fmt, <br>clippy-driver, cargo-clippy, rustdoc | ★ |
| deno | Deno | deno | ★ |
| java / jdk | Java | java, javac, jar, javadoc, jps, jcmd, jstat, keytool | ★ |
| kotlin | Kotlin | kotlin, kotlinc | ★ |

> 💡 "命令名"列是 mvm 命令中实际使用的名称，例如 `mvm install node@20` 中的 **node**；"可执行命令"列表示安装后通过 shim 可使用的命令。Node.js 还支持 npm 全局包安装，通过 `npm install -g <包名>` 安装的全局包命令（如 `tsc`、`prettier` 等）也会自动可用。

## 命令详解

### 全局选项

- `mvm --help` / `mvm -h`——显示帮助信息
- `mvm --version` / `mvm -v`——显示版本号

> 💡 直接运行 `mvm`（不带参数）也会显示帮助信息。

1. `mvm install`——安装版本
```bash
# 安装最新稳定版
mvm install node
mvm install bun
mvm install zig
mvm install go
mvm install python
mvm install rust
mvm install deno
mvm install java
mvm install kotlin

# 安装指定版本
mvm install node@20
mvm install node@lts
mvm install node@latest
mvm install node@20.18.0
mvm install bun@1.1.0
mvm install zig@0.13.0
mvm install go@1.23
mvm install python@3.12
mvm install rust@stable
mvm install deno@1.40
mvm install java@21
mvm install kotlin@2.0
```

2. `mvm use`——设置全局版本
```bash
# 指定版本
mvm use node@20
mvm use node@20.18.0

# 不指定版本，自动使用最新版
mvm use node
mvm use bun
mvm use go
mvm use python
mvm use rust
mvm use deno
```

3. `mvm unuse`——移除全局版本设置
```bash
mvm unuse node
mvm unuse bun
mvm unuse go
mvm unuse python
```

4. `mvm pin`——项目级版本锁定（强烈推荐）
```bash
# 进入项目目录
cd my-project
mvm pin node@20.18.0
mvm pin bun@1.2.3
mvm pin zig@0.15.2
mvm pin go@1.23.4
mvm pin python@3.12.4
mvm pin rust@1.80.0
```

5. `mvm list`——查看版本
```bash
# 查看所有
mvm list

# 查看特定语言
mvm list node
mvm list bun
mvm list go
mvm list python
```

6. `mvm current`——查看当前使用版本
```bash
# 查看所有工具的当前版本
mvm current

# 查看特定工具的当前版本
mvm current node
mvm current bun
mvm current go
mvm current python
```

7. `mvm uninstall`——卸载版本
```bash
mvm uninstall node@18.17.0
mvm uninstall zig@0.12.0
mvm uninstall go@1.21.0
mvm uninstall python@3.12.4
```

8. `mvm which`——查看工具可执行文件路径
```bash
# 查看当前使用的 node 的实际路径
mvm which node
mvm which bun
mvm which zig
mvm which go
mvm which python
```

9. `mvm run`——临时运行指定版本
```bash
# 使用指定版本临时运行命令
mvm run node@18 -- node -v
mvm run node@20 -- npm install
mvm run node@lts -- node -e "console.log(1)"

# 不指定版本，使用当前目录的版本
mvm run node -- npm -v
mvm run bun -- bun run dev
```

10. `mvm setup`——初始化工具脚本和 PATH
```bash
mvm setup
```

11. `mvm upgrade`——升级 mvm 自身
```bash
# 升级到最新版本
mvm upgrade

# 升级到指定版本（方便在不同版本之间切换）
mvm upgrade@v1.0.0

# 查看所有可用版本
mvm upgrade --list
mvm upgrade -l

# 重新安装当前版本（用于修复损坏的安装）
mvm upgrade --reinstall
mvm upgrade -r
```

12. `mvm config`——查看/设置配置
```bash
# 查看当前配置
mvm config list
mvm config ls

# 中国大陆用户一键配置（GitHub 代理 + Node 镜像 + Go 镜像 + Python 镜像 + Rust 镜像 + Java 镜像）
mvm config set china

# 单独设置配置
mvm config set node_mirror https://mirrors.aliyun.com/nodejs-release
mvm config set go_mirror https://mirrors.aliyun.com/golang
mvm config set python_mirror https://npmmirror.com/mirrors/python
mvm config set rust_mirror https://mirrors.ustc.edu.cn/rust-static
mvm config set java_mirror https://mirrors.aliyun.com/adoptium
mvm config set github_proxy https://cdn.gh-proxy.org/$URL

# 设置语言（支持 zh、en 及扩展语言代码）
mvm config set language zh
mvm config set language en
```

13. `mvm lang`——语言管理
```bash
# 设置当前语言（立即生效，支持任意语言代码）
mvm lang set zh
mvm lang set en

# 查看可用语言
mvm lang list

# 安装扩展语言包（JSON 文件路径）
mvm lang install /path/to/lang.json

# 移除扩展语言包
mvm lang remove <lang_code>
```

## 工作原理

mvm 的核心设计灵感来自 Volta，通过 **Shim 代理脚本 + 版本解析** 的方式实现多语言版本的无缝切换。

### 1. Shim 代理脚本

运行 `mvm setup` 时，mvm 会在 `$MVM_HOME/bin/` 目录下为每个工具创建轻量级的代理脚本（Shim）：

- **Unix（macOS/Linux）**：创建 shell 脚本，内容为 `#!/bin/sh\nmvm run node -- node "$@"`
- **Windows**：创建 `.ps1` 和 `.cmd` 文件，内容类似 `mvm run node -- node %*`

当你在终端输入 `node`、`bun`、`zig`、`go`、`python`、`rustc`、`deno`、`java`、`kotlinc` 等时，实际上执行的是这些代理脚本，它们会自动调用 `mvm run` 来解析正确的版本并执行对应的真实二进制文件。

### 2. PATH 配置

mvm 将 `$MVM_HOME/bin/` 添加到系统 PATH 中（通过修改 `.zshrc`、`.bash_profile` 等 shell 配置文件），确保代理脚本优先于系统自带的工具被调用。

### 3. 版本解析优先级

当执行工具命令时，mvm 按以下优先级确定使用哪个版本：

1. **项目级锁定**（`mvm pin`）：当前目录或父目录中的 `mvm.json`
2. **Volta 兼容**：项目目录中 `package.json` 的 `volta.node` 字段（仅 Node.js）
3. **全局默认**（`mvm use`）：`$MVM_HOME/config.json` 中的全局版本设置

> 💡 mvm 会向上搜索父目录，因此子目录中的命令也能继承父级的版本配置。

### 4. 安装流程

执行 `mvm install node@20` 时的流程：

1. 从官方发布地址（或配置的镜像/代理）下载归档文件
2. 校验 SHA256 哈希值（可通过 `--skip-verify` 跳过）
3. 解压到 `$MVM_HOME/tools/<tool>/<version>/` 目录
4. 在 `$MVM_HOME/installed.json` 中记录已安装版本

### 5. 配置体系

- **全局配置** `$MVM_HOME/config.json`：存储 GitHub 代理、Node 镜像、Go 镜像、Python 镜像、Rust 镜像、Java 镜像、语言偏好等设置
- **项目配置** `mvm.json`：存储项目级别的工具版本锁定（node、bun、zig、go、python、rust、deno、java、kotlin）

## Volta 兼容

mvm 兼容 Volta 的项目配置。如果项目目录下存在 Volta 的 `package.json`（包含 `volta.node` 字段），mvm 会自动读取其中的 Node.js 版本信息。

**示例：**
```json
{
  "name": "my-project",
  "volta": {
    "node": "20.0.0"
  }
}
```

> **提示：** mvm 会优先读取项目目录下的 `mvm.json` 配置，如不存在才会读取 Volta 的 `package.json`。

## 开发

1. 程序入口
```bash
# 普通运行（使用默认日志级别）
./scripts/run.sh install node@20

# 调试运行（自动设置 MVM_LOG_LEVEL=debug，运行后恢复原值）
./scripts/debug.sh install node
```

```powershell
# 普通运行（使用默认日志级别）
.\scripts\run.ps1 install node@20

# 调试运行（自动设置 MVM_LOG_LEVEL=debug，运行后恢复原值）
.\scripts\debug.ps1 install node
```

2. 本地构建产物测试
```bash
# 安装mvm，会自动将构建产物拷贝到$MVM_HOME
# 默认情况下，为了不与本地已经安装好的node、bun、npm、zig等冲突，会增加f_前缀。
# 比如: f_node -v
./scripts/install.sh
# 不需要前缀
./scripts/install.sh -np
```

3. 发布新版本
```bash
# 交互模式（上下键选择版本类型）
./scripts/bump-tag.sh

# 自动模式（默认 patch）
./scripts/bump-tag.sh -y

# 直接指定版本类型
./scripts/bump-tag.sh major
./scripts/bump-tag.sh minor
./scripts/bump-tag.sh patch

# 删除并重新发布当前 tag（用于更新已发布的 tag）
./scripts/bump-tag.sh -d
./scripts/bump-tag.sh -yd  # 自动模式
```

## Skills 配置

本项目的 `.claude` 目录包含 AI 编码助手相关的技能配置，参考了 [moonbitlang/skills](https://github.com/moonbitlang/skills) 项目。

**目录结构：**
- `skills/`——AI 编码助手技能定义（moonbit 相关、openspec 相关等）
- `commands/`——自定义命令配置
- `.claude-plugin/`——插件配置

**同步上游技能更新：**

`.claude` 目录的内容来自 [moonbitlang/skills](https://github.com/moonbitlang/skills) 仓库，但不使用 git submodule，而是通过脚本同步（避免 `.git` 目录冲突）。

**macOS / Linux**
```bash
./scripts/sync-skills.sh
```

**Windows（PowerShell）**
```powershell
.\scripts\sync-skills.ps1
```

> **提示：** 本地新增的自定义技能不会被同步脚本删除。