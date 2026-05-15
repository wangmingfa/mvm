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

**🌐 English | [中文](README.md)**

**mvm** (Multi Version Manager) —— One Tool to Manage Them All

</div>

No more headaches from installing different version managers for different languages.

mvm is a modern multi-language version management tool that supports Node.js, Bun, Zig, Go, and more. With just one command, you can freely switch between any language versions across projects — clean, efficient, and uncompromising.

Simple, unified, and blazing fast —— that's mvm.

> 💡 This tool is inspired by [Volta](https://volta.sh/).

## Install

**macOS / Linux**
```bash
curl -fsSL https://raw.githubusercontent.com/wangmingfa/mvm/main/scripts/install_online.sh | bash
```

**Windows (PowerShell)**

```powershell
powershell -c "irm https://raw.githubusercontent.com/wangmingfa/mvm/main/scripts/install_online.ps1|iex"
```

> **Note:** If you encounter garbled Chinese characters causing errors, follow [this guide](https://wangmingfa.github.io/docs/#/windows/powershell/garbled-text) to fix it.

## Platform Support

- macOS: ARM architecture (Apple Silicon)
- Windows: x86 architecture
- Linux: x86 architecture

## Commands

### Global Options

- `mvm --help` / `mvm -h`——Show help information
- `mvm --version` / `mvm -v`——Show version number

> 💡 Running `mvm` without arguments also shows help information.

1. `mvm install`——Install a version
```bash
# Install latest stable
mvm install node
mvm install bun
mvm install zig
mvm install go

# Install specific version
mvm install node@20
mvm install node@lts
mvm install node@latest
mvm install node@20.18.0
mvm install bun@1.1.0
mvm install zig@0.13.0
mvm install go@1.23
```

2. `mvm use`——Set global version
```bash
# Specify version
mvm use node@20
mvm use node@20.18.0

# Without version, auto-select the latest
mvm use node
mvm use bun
mvm use go
```

3. `mvm unuse`——Remove global version setting
```bash
mvm unuse node
mvm unuse bun
mvm unuse go
```

4. `mvm pin`——Project-level version lock (strongly recommended)
```bash
# Enter project directory
cd my-project
mvm pin node@20.18.0
mvm pin bun@1.2.3
mvm pin zig@0.15.2
mvm pin go@1.23.4
```

5. `mvm list`——List versions
```bash
# List all
mvm list

# List specific language
mvm list node
mvm list bun
mvm list go
```

6. `mvm current`——Show currently active version
```bash
# Show all tools' current versions
mvm current

# Show specific tool's current version
mvm current node
mvm current bun
mvm current go
```

7. `mvm uninstall`——Uninstall a version
```bash
mvm uninstall node@18.17.0
mvm uninstall zig@0.12.0
mvm uninstall go@1.21.0
```

8. `mvm which`——View tool executable path
```bash
mvm which node
mvm which bun
mvm which zig
mvm which go
```

9. `mvm run`——Temporarily run with a specific version
```bash
# Run a command with a specific version
mvm run node@18 -- node -v
mvm run node@20 -- npm install
mvm run node@lts -- node -e "console.log(1)"

# Without version, use the current directory's version
mvm run node -- npm -v
mvm run bun -- bun run dev
```

10. `mvm setup`——Initialize tool scripts and PATH
```bash
mvm setup
```

11. `mvm upgrade`——Upgrade mvm itself
```bash
# Upgrade to the latest version
mvm upgrade

# Upgrade to a specific version (for switching between versions)
mvm upgrade@v1.0.0

# List all available versions
mvm upgrade --list
mvm upgrade -l
```

12. `mvm config`——View or set configuration
```bash
# View current configuration
mvm config
mvm config list
mvm config ls

# One-click setup for users in China (GitHub proxy + Node mirror + Go mirror)
mvm config set china

# Set individual configuration
mvm config set node_mirror https://npm.taobao.org/mirrors/node
mvm config set go_mirror https://mirrors.aliyun.com/golang
mvm config set github_proxy https://cdn.gh-proxy.org/

# Hide/show startup logo (shown by default)
mvm config set logo false
mvm config set logo true
```

## Volta Compatibility

mvm is compatible with Volta's project configuration. If a Volta `package.json` (with `volta.node` field) exists in the project directory, mvm will automatically read the Node.js version from it.

**Example:**
```json
{
  "name": "my-project",
  "volta": {
    "node": "20.0.0"
  }
}
```

> **Note:** mvm prioritizes reading `mvm.json` from the project directory. If it doesn't exist, it will fall back to Volta's `package.json`.

## Development

1. Entry point
```bash
# Equivalent to production: mvm install node@20
moon run cmd/main install node@20
# Debug mode, equivalent to production: mvm install node
MVM_LOG_LEVEL=debug ./scripts/debug.sh install node
```

```powershell
$env:MVM_LOG_LEVEL="debug"; ./scripts/debug.ps1 install node
```

2. Test local build
```bash
# Install mvm, automatically copies build artifacts to $MVM_HOME
# By default, to avoid conflicts with locally installed node, bun, npm, zig, etc., a f_ prefix is added.
# Example: f_node -v
./scripts/install.sh
# Without prefix
./scripts/install.sh -np
```

3. Release new version
```bash
# Interactive mode (up/down keys to select version type)
./scripts/bump-tag.sh

# Auto mode (default patch)
./scripts/bump-tag.sh -y

# Specify version type directly
./scripts/bump-tag.sh major
./scripts/bump-tag.sh minor
./scripts/bump-tag.sh patch

# Delete and re-release current tag (to update an existing tag)
./scripts/bump-tag.sh -d
./scripts/bump-tag.sh -yd  # auto mode
```

## Skills Submodule

This project uses [moonbitlang/skills](https://github.com/moonbitlang/skills) as a submodule.

**Add submodule:**
> Already added to this project, no need to add again
```bash
git submodule add https://github.com/moonbitlang/skills.git .claude
```

**Update submodule:**
```bash
git submodule update --init --recursive
```