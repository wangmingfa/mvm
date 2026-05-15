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

mvm 是一款现代化的多语言版本管理工具，支持 Node.js、Bun、Zig、Go 以及更多语言。只需一条命令，你就可以在项目之间自由切换任意语言的版本，干净、高效、毫不妥协。

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

# 安装指定版本
mvm install node@20
mvm install node@lts
mvm install node@latest
mvm install node@20.18.0
mvm install bun@1.1.0
mvm install zig@0.13.0
mvm install go@1.23
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
```

3. `mvm unuse`——移除全局版本设置
```bash
mvm unuse node
mvm unuse bun
mvm unuse go
```

4. `mvm pin`——项目级版本锁定（强烈推荐）
```bash
# 进入项目目录
cd my-project
mvm pin node@20.18.0
mvm pin bun@1.2.3
mvm pin zig@0.15.2
mvm pin go@1.23.4
```

5. `mvm list`——查看版本
```bash
# 查看所有
mvm list

# 查看特定语言
mvm list node
mvm list bun
mvm list go
```

6. `mvm current`——查看当前使用版本
```bash
# 查看所有工具的当前版本
mvm current

# 查看特定工具的当前版本
mvm current node
mvm current bun
mvm current go
```

7. `mvm uninstall`——卸载版本
```bash
mvm uninstall node@18.17.0
mvm uninstall zig@0.12.0
mvm uninstall go@1.21.0
```

8. `mvm which`——查看工具可执行文件路径
```bash
# 查看当前使用的 node 的实际路径
mvm which node
mvm which bun
mvm which zig
mvm which go
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
```

12. `mvm config`——查看/设置配置
```bash
# 查看当前配置
mvm config list
mvm config ls

# 中国大陆用户一键配置（GitHub 代理 + Node 镜像 + Go 镜像）
mvm config set china

# 单独设置配置
mvm config set node_mirror https://mirrors.aliyun.com/nodejs-release
mvm config set go_mirror https://mirrors.aliyun.com/golang
mvm config set github_proxy https://cdn.gh-proxy.org/$URL

# 关闭/开启启动 logo 显示（默认显示）
mvm config set logo false
mvm config set logo true
```

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
# 等同生产：mvm install node@20
moon run cmd/main install node@20
# 调试模式运行，等同生产：mvm install node
MVM_LOG_LEVEL=debug ./scripts/debug.sh install node
```

```powershell
$env:MVM_LOG_LEVEL="debug"; ./scripts/debug.ps1 install node
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

## Skills 子模块

本项目使用 [moonbitlang/skills](https://github.com/moonbitlang/skills) 作为子模块。

**添加子模块：**
> 项目中已经添加此子模块，无需再次添加
```bash
git submodule add https://github.com/moonbitlang/skills.git .claude
```

**更新子模块：**
```bash
git submodule update --init --recursive
```