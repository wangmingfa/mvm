# Git Hooks

## Pre-commit Hook

This pre-commit hook performs automatic checks before finalizing your commit.

### Features

1. **自动同步 install.config**：将 `install.config` 中的 `PREFIX` 和 `TOOLS` 配置自动更新到 `install.sh` 和 `install.ps1` 中
2. **自动 moon check**：运行 moon check 检查代码

### Usage Instructions

To use this pre-commit hook:

1. Make the hook executable if it isn't already:
   ```bash
   chmod +x .githooks/pre-commit
   ```

2. Configure Git to use the hooks in the .githooks directory:
   ```bash
   git config core.hooksPath .githooks
   ```

3. The hook will automatically run when you execute `git commit`

### Workflow

1. 修改 `install.config` 中的配置
2. 运行 `git commit`
3. Pre-commit hook 会自动同步配置到 `install.sh` 和 `install.ps1`，并添加这些修改到同一个 commit 中
