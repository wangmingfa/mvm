# Design: Rewrite miniz.c in Pure MoonBit

## Overview

用纯 MoonBit 语言实现 miniz.c 的核心功能，包括 DEFLATE 压缩/解压、zlib 封装、ZIP 归档读写。最终移除所有 C 代码依赖和系统命令调用。

## Architecture

### 包结构

在 `zip/` 包下创建子包，按功能分层：

```
zip/
├── moon.pkg              # 移除 native-stub，新增子包依赖
├── zip.mbt               # 保持公开 API 不变（unzip/zip）
├── checksum/
│   ├── moon.pkg
│   ├── adler32.mbt       # Adler-32 校验和
│   └── crc32.mbt         # CRC-32 校验和
├── deflate/
│   ├── moon.pkg
│   ├── bitbuf.mbt        # 位缓冲区读写工具
│   ├── huffman.mbt       # Huffman 编码/解码树
│   ├── compress.mbt      # DEFLATE 压缩器 (tdefl 等价)
│   └── decompress.mbt    # DEFLATE 解压器 (tinfl 等价)
├── zlib/
│   ├── moon.pkg
│   └── zlib.mbt          # zlib 格式封装 (RFC 1950)
├── reader/
│   ├── moon.pkg
│   ├── structs.mbt       # ZIP 数据结构/常量
│   ├── endian.mbt        # Little-endian 读写
│   └── reader.mbt        # ZIP 归档读取
└── writer/
    ├── moon.pkg
    └── writer.mbt        # ZIP 归档写入
```

### 1. Checksum 层 (`zip/checksum/`)

**Adler-32** (RFC 1950):
- 直接翻译 miniz.c 的 `mz_adler32()` 实现
- 使用 MoonBit 的 `@math.land` 等位运算确保 32 位无符号算术
- 核心：`s1 += byte; s2 += s1; s1 %= 65521; s2 %= 65521`

**CRC-32**:
- 使用 miniz.c 的 256 项查找表实现
- 预计算查找表作为 `const` 数组
- 核心：`crc = (crc >> 8) ^ table[(crc ^ byte) & 0xFF]`

### 2. DEFLATE 层 (`zip/deflate/`)

**BitBuffer** (`bitbuf.mbt`):
- `BitReader`: 从字节数组读取位流，支持 `read_bits(n)` / `peek_bits(n)`
- `BitWriter`: 向字节数组写入位流，支持 `write_bits(value, n)` / `flush()`
- 使用 `UInt` 类型作为位缓冲区

**Huffman** (`huffman.mbt`):
- `HuffmanTree`: 解码用的查找表 + 树结构
- `build_huffman_tree(code_lengths)`: 从码长构建解码树
- `decode_symbol(reader, tree)`: 从位流解码一个符号
- 固定 Huffman 表（RFC 1951 §3.2.6）作为预定义常量
- 编码端：频率统计 → 码长计算 → 规范 Huffman 码生成

**Compressor** (`compress.mbt`):
- LZ77 匹配：哈希链查找最长匹配
- 支持 static / dynamic / raw 三种块类型
- 压缩级别 0-9（级别 0 = stored，1 = 快速，6 = 默认，9 = 最佳）
- 核心 API：
  ```moonbit
  pub fn deflate_compress(data : Bytes, level : Int) -> Bytes
  pub fn deflate_compress_to_buffer(data : Bytes, level : Int) -> Buffer
  ```

**Decompressor** (`decompress.mbt`):
- 状态机方式实现（替代 miniz.c 的 coroutine 宏）
- 解码流程：读块头 → 按块类型解码（stored/fixed/dynamic）→ LZ77 回引
- 32KB 滑动窗口
- 核心 API：
  ```moonbit
  pub fn inflate_decompress(data : Bytes, expected_size : Int) -> Result[Bytes, String]
  pub fn inflate_decompress_to_buffer(data : Bytes) -> Result[Buffer, String]
  ```

### 3. Zlib 层 (`zip/zlib/`)

- `compress(data, level)`: 写入 zlib 头（CMF + FLG）+ DEFLATE 数据 + Adler-32 校验
- `decompress(data)`: 验证 zlib 头 → DEFLATE 解压 → 验证 Adler-32
- 核心 API：
  ```moonbit
  pub fn zlib_compress(data : Bytes, level : Int) -> Bytes
  pub fn zlib_decompress(data : Bytes) -> Result[Bytes, String]
  ```

### 4. ZIP Reader (`zip/reader/`)

**数据结构** (`structs.mbt`):
- `ZipFileEntry`: 文件名、压缩方式、压缩/未压缩大小、CRC-32、本地头偏移
- `ZipArchive`: 文件条目列表、归档大小
- 常量：签名值（PK\x03\x04, PK\x01\x02, PK\x05\x06）、压缩方法（stored=0, deflated=8）

**Endian** (`endian.mbt`):
- `read_le16/read_le32/read_le64`: 从字节数组读取小端整数
- `write_le16/write_le32/write_le64`: 写入小端整数到字节数组

**Reader** (`reader.mbt`):
- 从文件末尾查找 End of Central Directory Record（EOCD）
- 解析 Central Directory 获取所有文件条目信息
- 解析 Local File Header 定位文件数据
- 使用 inflate 解压 deflated 文件，stored 文件直接拷贝
- ZIP64 支持：当 EOCD 或 Central Directory 中的值为 0xFFFFFFFF 时读取 ZIP64 扩展
- 核心 API：
  ```moonbit
  pub fn open_zip(path : String) -> Result[ZipArchive, String]
  pub fn extract_all(archive : ZipArchive, output_dir : String, on_progress? : (Float) -> Unit) -> Result[Unit, String]
  pub fn extract_file(archive : ZipArchive, index : Int, output_path : String) -> Result[Unit, String]
  ```

### 5. ZIP Writer (`zip/writer/`)

- 逐个写入 Local File Header + 文件数据（deflate 压缩或 stored）
- 在内存中构建 Central Directory
- 写完所有文件后写入 Central Directory + EOCD
- 支持目录创建（文件名以 `/` 结尾）
- 核心 API：
  ```moonbit
  pub fn create_zip(output_path : String) -> ZipWriter
  pub fn add_file(writer : ZipWriter, name : String, data : Bytes, compress_level : Int) -> Unit
  pub fn add_directory(writer : ZipWriter, name : String) -> Unit
  pub fn add_directory_recursive(writer : ZipWriter, base_dir : String, dir_path : String) -> Unit
  pub fn finalize(writer : ZipWriter) -> Result[Unit, String]
  ```

### 6. 公开 API 适配 (`zip/zip.mbt`)

保持现有接口不变：

```moonbit
// unzip: 使用 zip/reader 替代 C FFI
pub fn unzip(
  file_path : String,
  output_dir : String,
  on_progress? : (Float) -> Unit,
) -> Bool

// zip: 使用 zip/writer 替代系统命令，不再需要 async
pub async fn zip(
  dir : String,
  zip_file_path : String,
  cwd? : StringView,
) -> Bool
```

### 7. moon.pkg 变更

```
// 移除:
options("native-stub": [ "zip.c", "miniz.c" ])

// 新增依赖:
import {
  "username/mvm/zip/checksum",
  "username/mvm/zip/deflate",
  "username/mvm/zip/zlib",
  "username/mvm/zip/reader",
  "username/mvm/zip/writer",
  // ... existing deps
}
```

## Files to Create

| File | Purpose |
|------|---------|
| `zip/checksum/moon.pkg` | 包定义 |
| `zip/checksum/adler32.mbt` | Adler-32 实现 |
| `zip/checksum/crc32.mbt` | CRC-32 实现 |
| `zip/deflate/moon.pkg` | 包定义 |
| `zip/deflate/bitbuf.mbt` | 位缓冲区 I/O |
| `zip/deflate/huffman.mbt` | Huffman 编码/解码 |
| `zip/deflate/compress.mbt` | DEFLATE 压缩 |
| `zip/deflate/decompress.mbt` | DEFLATE 解压 |
| `zip/zlib/moon.pkg` | 包定义 |
| `zip/zlib/zlib.mbt` | zlib 格式封装 |
| `zip/reader/moon.pkg` | 包定义 |
| `zip/reader/structs.mbt` | ZIP 数据结构 |
| `zip/reader/endian.mbt` | 小端读写 |
| `zip/reader/reader.mbt` | ZIP 读取 |
| `zip/writer/moon.pkg` | 包定义 |
| `zip/writer/writer.mbt` | ZIP 写入 |

## Files to Modify

| File | Change |
|------|--------|
| `zip/zip.mbt` | 重写 unzip/zip 使用纯 MoonBit 实现 |
| `zip/moon.pkg` | 移除 native-stub，新增子包依赖 |

## Files to Delete

| File | Reason |
|------|--------|
| `zip/miniz.c` | 已被纯 MoonBit 替代 |
| `zip/miniz.h` | 已被纯 MoonBit 替代 |
| `zip/zip.c` | 不再需要 C 包装器 |

## Testing Strategy

### 交叉验证：MoonBit 实现 vs 系统命令

每个阶段都包含与系统工具的输出对比测试，确保纯 MoonBit 实现与标准工具结果一致。

#### 1. Checksum 对比

| 测试项 | MoonBit | 系统命令 | 对比方式 |
|--------|---------|----------|----------|
| Adler-32 | `adler32(data)` | 用 `gzip` 压缩数据（zlib 格式），MoonBit 的 `zlib_decompress` 解压并校验 Adler-32 | 解压成功且内容一致 |
| CRC-32 | `crc32(data)` | 用 `zip` 打包单文件，MoonBit 的 reader 解析 Central Directory 中的 CRC-32 字段 | CRC-32 值相等 |

测试数据：空串、短字符串、长文本（>5552 字节触发 Adler-32 分块）、二进制数据。

**具体方法：**
- **Adler-32**：`echo -n "testdata" | gzip > /tmp/test.gz` → MoonBit 读取 gzip 文件，提取 DEFLATE 流并用 `adler32()` 校验，与解压内容对比
- **CRC-32**：`echo -n "testdata" > /tmp/test.txt && zip /tmp/test.zip /tmp/test.txt` → MoonBit 解析 ZIP 的 Central Directory 获取系统计算的 CRC-32，与 `crc32(data)` 对比

#### 2. DEFLATE 压缩对比

| 测试项 | MoonBit | 系统命令 | 对比方式 |
|--------|---------|----------|----------|
| 压缩 → 解压 roundtrip | `inflate(deflate(data))` | — | 解压后 == 原始数据 |
| 兼容性：MoonBit 压缩 → 系统解压 | `deflate(data)` | `python3 -c "import zlib; zlib.decompress(moonbit_output)"` | 系统能解压 MoonBit 输出 |
| 兼容性：系统压缩 → MoonBit 解压 | `inflate(data)` | `python3 -c "import zlib; zlib.compress(input)"` | MoonBit 能解压系统输出 |

测试数据：空串、重复文本（高压缩比）、随机二进制（低压缩比）、大文件（>1MB）。

#### 3. ZIP 对比

| 测试项 | MoonBit | 系统命令 | 对比方式 |
|--------|---------|----------|----------|
| MoonBit 创建 ZIP → 系统解压 | `zip()` | `unzip -d output_dir moonbit.zip` | 解压后文件内容一致 |
| 系统创建 ZIP → MoonBit 解压 | `unzip()` | `zip -r system.zip dir` | 解压后文件内容一致 |
| 多文件目录结构 | `zip()` + `unzip()` | `zip` + `unzip` | 目录结构、文件内容、文件大小完全一致 |
| 含子目录 | `zip()` + `unzip()` | `zip` + `unzip` | 递归目录结构一致 |
| 空文件 | `zip()` + `unzip()` | `zip` + `unzip` | 空文件正确处理 |
| 大文件（>1MB） | `zip()` + `unzip()` | `zip` + `unzip` | 内容一致、CRC-32 一致 |

#### 测试辅助函数

在 `zip/` 包中创建测试辅助文件 `test_helper.mbt`：

```moonbit
// 调用系统命令生成/解压 ZIP，用于交叉验证
fn system_zip(dir : String, output : String) -> Bool
fn system_unzip(zip_path : String, output_dir : String) -> Bool
fn read_file_bytes(path : String) -> Bytes
fn files_equal(path_a : String, path_b : String) -> Bool
fn dir_tree_equal(dir_a : String, dir_b : String) -> Bool
```

## Key Design Decisions

1. **不使用 FFI / C 代码**：所有算法纯 MoonBit 实现
2. **不使用系统命令**：ZIP 创建用纯 MoonBit writer 替代 `zip` / `Compress-Archive`
3. **状态机替代 coroutine**：miniz.c 的 tinfl 使用 C 宏模拟协程，MoonBit 中改用显式状态机
4. **MoonBit Buffer 类型**：使用 MoonBit 原生 `Buffer`/`Bytes` 类型管理内存，无需手动 malloc/free
5. **Result 类型错误处理**：使用 MoonBit 的 `Result[T, E]` 替代 C 的返回码
6. **压缩级别**：支持 0（stored）、1（快速）、6（默认）、9（最佳），满足 ZIP 需求即可
