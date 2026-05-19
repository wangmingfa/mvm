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

mvm is a modern multi-language version management tool that supports Node.js, Bun, Zig, Go, Python, Rust, Deno, Java, Kotlin, and more. With just one command, you can freely switch between any language versions across projects — clean, efficient, and uncompromising.

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

## Supported Tools

mvm supports 9 development tools, each with full version management commands (install, use, pin, unuse, uninstall, list, current, which, run).

| Command Name | Tool | Executable Commands |
|--------------|------|---------------------|
| node | Node.js | node, npm, npx, corepack, npm global packages |
| bun | Bun | bun, bunx |
| zig | Zig | zig |
| go | Go | go, gofmt |
| python / python3 | Python | python3, python |
| rust / rustc | Rust | rustc, cargo, rustfmt, cargo-fmt, clippy-driver, cargo-clippy, rustdoc |
| deno | Deno | deno |
| java / jdk | Java | java, javac, jar, javadoc, jps, jcmd, jstat, keytool |
| kotlin | Kotlin | kotlin, kotlinc |

> 💡 The "Command Name" column is the actual name used in mvm commands, e.g., **node** in `mvm install node@20`; the "Executable Commands" column shows available shim commands after installation. Node.js also supports npm global package installation — commands from globally installed packages (e.g., `tsc`, `prettier`) via `npm install -g <package>` are automatically available.

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
mvm install python
mvm install rust
mvm install deno
mvm install java
mvm install kotlin

# Install specific version
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

2. `mvm use`——Set global version
```bash
# Specify version
mvm use node@20
mvm use node@20.18.0

# Without version, auto-select the latest
mvm use node
mvm use bun
mvm use go
mvm use python
mvm use rust
mvm use deno
```

3. `mvm unuse`——Remove global version setting
```bash
mvm unuse node
mvm unuse bun
mvm unuse go
mvm unuse python
```

4. `mvm pin`——Project-level version lock (strongly recommended)
```bash
# Enter project directory
cd my-project
mvm pin node@20.18.0
mvm pin bun@1.2.3
mvm pin zig@0.15.2
mvm pin go@1.23.4
mvm pin python@3.12.4
mvm pin rust@1.80.0
```

5. `mvm list`——List versions
```bash
# List all
mvm list

# List specific language
mvm list node
mvm list bun
mvm list go
mvm list python
```

6. `mvm current`——Show currently active version
```bash
# Show all tools' current versions
mvm current

# Show specific tool's current version
mvm current node
mvm current bun
mvm current go
mvm current python
```

7. `mvm uninstall`——Uninstall a version
```bash
mvm uninstall node@18.17.0
mvm uninstall zig@0.12.0
mvm uninstall go@1.21.0
mvm uninstall python@3.12.4
```

8. `mvm which`——View tool executable path
```bash
mvm which node
mvm which bun
mvm which zig
mvm which go
mvm which python
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

# Reinstall the current version (useful for repairing a corrupted installation)
mvm upgrade --reinstall
mvm upgrade -r
```

12. `mvm config`——View or set configuration
```bash
# View current configuration
mvm config
mvm config list
mvm config ls

# One-click setup for users in China (GitHub proxy + Node mirror + Go mirror + Python mirror + Rust mirror + Java mirror)
mvm config set china

# Set individual configuration
mvm config set node_mirror https://npm.taobao.org/mirrors/node
mvm config set go_mirror https://mirrors.aliyun.com/golang
mvm config set python_mirror https://npmmirror.com/mirrors/python
mvm config set rust_mirror https://mirrors.ustc.edu.cn/rust-static
mvm config set java_mirror https://mirrors.aliyun.com/adoptium
mvm config set github_proxy https://cdn.gh-proxy.org/
```

## How It Works

mvm's core design is inspired by Volta, achieving seamless multi-language version switching through **Shim proxy scripts + version resolution**.

### 1. Shim Proxy Scripts

When you run `mvm setup`, mvm creates lightweight proxy scripts (shims) in the `$MVM_HOME/bin/` directory for each tool:

- **Unix (macOS/Linux)**: Creates shell scripts with content like `#!/bin/sh\nmvm run node -- node "$@"`
- **Windows**: Creates `.ps1` and `.cmd` files with content like `mvm run node -- node %*`

When you type `node`, `bun`, `zig`, `go`, `python`, `rustc`, `deno`, `java`, `kotlinc`, etc. in your terminal, you're actually executing these proxy scripts, which automatically call `mvm run` to resolve the correct version and execute the corresponding real binary.

### 2. PATH Configuration

mvm adds `$MVM_HOME/bin/` to the system PATH (by modifying shell profile files like `.zshrc`, `.bash_profile`, etc.), ensuring the proxy scripts are called before any system-installed tools.

### 3. Version Resolution Priority

When executing a tool command, mvm determines the version to use in this order:

1. **Project-level pin** (`mvm pin`): `mvm.json` in the current directory or parent directories
2. **Volta compatibility**: `volta.node` field in the project's `package.json` (Node.js only)
3. **Global default** (`mvm use`): Global version setting in `$MVM_HOME/config.json`

> 💡 mvm searches upward through parent directories, so commands in subdirectories inherit the parent's version configuration.

### 4. Installation Flow

When you run `mvm install node@20`:

1. Download the archive from the official release URL (or configured mirror/proxy)
2. Verify the SHA256 checksum (can be skipped with `--skip-verify`)
3. Extract to `$MVM_HOME/tools/<tool>/<version>/` directory
4. Record the installed version in `$MVM_HOME/installed.json`

### 5. Configuration System

- **Global config** `$MVM_HOME/config.json`: Stores GitHub proxy, Node mirror, Go mirror, Python mirror, Rust mirror, Java mirror settings
- **Project config** `mvm.json`: Stores project-level tool version pins (node, bun, zig, go, python, rust, deno, java, kotlin)

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
# Normal run (default log level)
./scripts/run.sh install node@20

# Debug run (auto sets MVM_LOG_LEVEL=debug, restores original value after)
./scripts/debug.sh install node
```

```powershell
# Normal run (default log level)
.\scripts\run.ps1 install node@20

# Debug run (auto sets MVM_LOG_LEVEL=debug, restores original value after)
.\scripts\debug.ps1 install node
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

## Skills Configuration

The `.claude` directory in this project contains AI coding assistant skill configurations, referencing the [moonbitlang/skills](https://github.com/moonbitlang/skills) project.

**Directory structure:**
- `skills/`——AI coding assistant skill definitions (moonbit-related, openspec-related, etc.)
- `commands/`——Custom command configurations
- `.claude-plugin/`——Plugin configurations

**Sync upstream skill updates:**

The `.claude` directory content comes from the [moonbitlang/skills](https://github.com/moonbitlang/skills) repository, but does not use git submodule. Instead, it's synced via script (avoiding `.git` directory conflicts).

**macOS / Linux**
```bash
./scripts/sync-skills.sh
```

**Windows (PowerShell)**
```powershell
.\scripts\sync-skills.ps1
```

> **Note:** Local custom skills will not be deleted by the sync script.