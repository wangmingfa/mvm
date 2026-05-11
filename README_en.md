# wangmingfa/mvm

**🌐 English | [中文](README.md)**

**mvm** (Multi Version Manager) —— One Tool to Manage Them All

No more headaches from installing different version managers for different languages.

mvm is a modern multi-language version management tool that supports Node.js, Bun, Zig, and more. With just one command, you can freely switch between any language versions across projects — clean, efficient, and uncompromising.

Simple, unified, and blazing fast —— that's mvm.

> 💡 This tool is inspired by [Volta](https://volta.sh/).

## Install

**macOS / Linux**
```bash
curl -fsSL https://raw.githubusercontent.com/wangmingfa/mvm/main/install.sh | bash -s -- --online
```

**Windows (PowerShell)**

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/wangmingfa/mvm/main/install.ps1))) --online
```

> **Note:** If you encounter garbled Chinese characters causing errors, follow [this guide](https://wangmingfa.github.io/docs/#/windows/powershell/garbled-text) to fix it.

## Platform Support

- macOS: ARM architecture (Apple Silicon)
- Windows: x86 architecture
- Linux: x86 architecture

## Commands

1. `mvm install`——Install a version
```bash
# Install latest stable
mvm install node
mvm install bun
mvm install zig

# Install specific version
mvm install node@20
mvm install node@lts
mvm install node@latest
mvm install node@20.18.0
mvm install bun@1.1.0
mvm install zig@0.13.0
```

2. `mvm use`——Set global version
```bash
mvm use node@20
mvm use node@20.18.0
```

3. `mvm pin`——Project-level version lock (strongly recommended)
```bash
# Enter project directory
cd my-project
mvm pin node@20.18.0
mvm pin bun@1.2.3
mvm pin zig@0.15.2
```

4. `mvm list`——List versions
```bash
# List all
mvm list

# List specific language
mvm list node
mvm list bun
```

5. `mvm uninstall`——Uninstall a version
```bash
mvm uninstall node@18.17.0
mvm uninstall zig@0.12.0
```

6. `mvm config`——View or set configuration
```bash
# View current configuration
mvm config
mvm config list
mvm config ls

# One-click setup for users in China (GitHub proxy + Node mirror)
mvm config set china

# Set individual configuration
mvm config set node_mirror https://npm.taobao.org/mirrors/node
mvm config set github_proxy https://cdn.gh-proxy.org/
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
# Debug mode, equivalent to production: node -v
MVM_LOG_LEVEL=debug ./executor.sh node -v
```

```powershell
$env:MVM_LOG_LEVEL="debug"; ./executor.ps1  node -v
```

2. Test local build
```bash
# Install mvm, automatically copies build artifacts to $MVM_HOME
# By default, to avoid conflicts with locally installed node, bun, npm, zig, etc., a f_ prefix is added.
# Example: f_node -v
./install.sh
# Without prefix
./install.sh -np
```

3. Release new version
```bash
# Interactive mode (up/down keys to select version type)
./bump-tag.sh

# Auto mode (default patch)
./bump-tag.sh -y

# Specify version type directly
./bump-tag.sh major
./bump-tag.sh minor
./bump-tag.sh patch

# Delete and re-release current tag (to update an existing tag)
./bump-tag.sh -d
./bump-tag.sh -yd  # auto mode
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