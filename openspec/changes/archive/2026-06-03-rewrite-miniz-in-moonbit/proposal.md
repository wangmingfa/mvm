# Proposal: Rewrite miniz.c in Pure MoonBit

## Motivation

当前项目的 `zip` 包依赖 C 语言库 `miniz.c`（约 7900 行）通过 FFI 实现 ZIP 解压功能，同时 `zip()` 函数通过调用系统命令（Unix 的 `zip`、Windows 的 `Compress-Archive`）来创建 ZIP 文件。这带来以下问题：

1. **跨平台依赖**：依赖系统安装 `zip` 命令，Windows 依赖 PowerShell，不够自包含
2. **FFI 复杂性**：C 代码调试困难，与 MoonBit 的类型安全体系脱节
3. **维护负担**：miniz.c 是第三方 C 代码，存在潜在安全漏洞难以审计
4. **功能受限**：当前仅暴露了 `unzip` 功能，压缩功能完全依赖外部命令

## Goals

1. **纯 MoonBit 实现**：用 MoonBit 语言完整改写 miniz.c 的核心功能，不依赖任何 C 代码或系统命令
2. **DEFLATE 压缩/解压**：实现 RFC 1951 DEFLATE 算法（压缩与解压）
3. **zlib 封装**：实现 RFC 1950 zlib 格式（Adler-32 校验 + DEFLATE）
4. **ZIP 读取**：实现 ZIP 归档读取与解压（含 ZIP64 支持）
5. **ZIP 写入**：实现 ZIP 归档创建与压缩写入，替代系统 `zip` 命令
6. **API 兼容**：保持现有 `zip` 包的公开 API（`unzip()`、`zip()`）不变
7. **移除 C 依赖**：最终移除 `miniz.c`、`miniz.h`、`zip.c` 和 `moon.pkg` 中的 `native-stub` 配置

## Non-Goals

- 不实现 PNG 写入功能（miniz.c 中的 `tdefl_write_image_to_png_file_in_memory`），项目不需要
- 不实现加密 ZIP 支持
- 不追求与 zlib 完全一致的 API 表面，只提供项目所需的高层接口
- 不实现 gzip 格式

## Impact

- **zip 包**：完全移除 C 代码，改为纯 MoonBit 实现
- **moon.pkg**：移除 `native-stub` 配置
- **构建**：不再需要 C 编译器来处理 zip 包
- **跨平台**：ZIP 读写在所有 MoonBit 支持的平台上行为一致
- **依赖包**：`command` 和 `cmd/command` 包使用了 `zip` 包，但公开 API 不变，无需修改
- **性能**：纯 MoonBit 实现可能比 C 版本慢，但对于版本管理工具的典型场景（解压工具包）可接受
