# username/mvm

**mvm** - One Tool to Manage Them All

再也不用为不同语言安装不同的版本管理器而头疼了。

mvm 是一款现代化的多语言版本管理工具，支持 Node.js、Npm、Bun、Zig 以及更多语言。只需一条命令，你就可以在项目之间自由切换任意语言的版本，干净、高效、毫不妥协。

简单、统一、极快 —— 这就是 mvm。

## 安装

```bash
curl -fsSL https://raw.githubusercontent.com/<username>/mvm/main/install.sh | bash -s -- --online
```

## 命令详解

1. `mvm install`--安装版本
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

2. `mvm use`--设置全局版本
```bash
mvm use node@20
mvm use node@20.18.0
```

3. `mvm pin`--项目级版本锁定（强烈推荐）
```bash
# 进入项目目录
cd my-project
mvm pin node@20.18.0
mvm pin bun@1.2.3
mvm pin zig@0.15.2
```

4. `mvm list`—— 查看版本
```bash
# 查看所有
mvm list

# 查看特定语言
mvm list node
mvm list bun
```

5. `mvm uninstall`—— 卸载版本
```bash
mvm uninstall node@18.17.0
mvm uninstall zig@0.12.0
```

## 开发

1. 程序入口
```bash
# 等同生产：mvm install node@20
moon run cmd/main install node@20
# 调试模式运行，等同生产：node -v
MVM_LOG_LEVEL=debug ./executor.sh node -v
```