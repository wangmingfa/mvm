# wangmingfa/mvm

**🌐 [English](README_en.md) | 中文**

mvm（Multi Version Manager）——One Tool to Manage Them All

再也不用为不同语言安装不同的版本管理器而头疼了。

mvm 是一款现代化的多语言版本管理工具，支持 Node.js、Bun、Zig 以及更多语言。只需一条命令，你就可以在项目之间自由切换任意语言的版本，干净、高效、毫不妥协。

简单、统一、极快 —— 这就是 mvm。

> 💡 此工具灵感来源于 [Volta](https://volta.sh/)。

## 安装

**macOS / Linux**
```bash
curl -fsSL https://raw.githubusercontent.com/wangmingfa/mvm/main/install.sh | bash -s -- --online
```

**Windows（PowerShell）**

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/wangmingfa/mvm/main/install.ps1))) --online
```

> **提示：** 如果脚本执行时遇到中文乱码导致报错，请按照 [此文档](https://wangmingfa.github.io/docs/#/windows/powershell/garbled-text) 进行操作。

## 平台支持

- macOS：ARM 架构（Apple Silicon）
- Windows：x86 架构
- Linux：x86 架构

## 命令详解

1. `mvm install`——安装版本
```bash
# 安装最新稳定版
mvm install node
mvm install bun
mvm install zig

# 安装指定版本
mvm install node@20
mvm install node@lts
mvm install node@latest
mvm install node@20.18.0
mvm install bun@1.1.0
mvm install zig@0.13.0
```

2. `mvm use`——设置全局版本
```bash
mvm use node@20
mvm use node@20.18.0
```

3. `mvm pin`——项目级版本锁定（强烈推荐）
```bash
# 进入项目目录
cd my-project
mvm pin node@20.18.0
mvm pin bun@1.2.3
mvm pin zig@0.15.2
```

4. `mvm list`——查看版本
```bash
# 查看所有
mvm list

# 查看特定语言
mvm list node
mvm list bun
```

5. `mvm uninstall`——卸载版本
```bash
mvm uninstall node@18.17.0
mvm uninstall zig@0.12.0
```

6. `mvm which`——查看工具可执行文件路径
```bash
# 查看当前使用的 node 的实际路径
mvm which node
mvm which bun
mvm which zig
```

7. `mvm config`——查看/设置配置
```bash
# 查看当前配置
mvm config list
mvm config ls

# 中国大陆用户一键配置（GitHub 代理 + Node 镜像）
mvm config set china

# 单独设置配置
mvm config set node_mirror https://mirrors.aliyun.com/nodejs-release
mvm config set github_proxy https://cdn.gh-proxy.org/$URL
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
# 调试模式运行，等同生产：node -v
MVM_LOG_LEVEL=debug ./executor.sh node -v
```

```powershell
$env:MVM_LOG_LEVEL="debug"; ./executor.ps1  node -v
```

2. 本地构建产物测试
```bash
# 安装mvm，会自动将构建产物拷贝到$MVM_HOME
# 默认情况下，为了不与本地已经安装好的node、bun、npm、zig等冲突，会增加f_前缀。
# 比如: f_node -v
./install.sh
# 不需要前缀
./install.sh -np
```

3. 发布新版本
```bash
# 交互模式（上下键选择版本类型）
./bump-tag.sh

# 自动模式（默认 patch）
./bump-tag.sh -y

# 直接指定版本类型
./bump-tag.sh major
./bump-tag.sh minor
./bump-tag.sh patch

# 删除并重新发布当前 tag（用于更新已发布的 tag）
./bump-tag.sh -d
./bump-tag.sh -yd  # 自动模式
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
