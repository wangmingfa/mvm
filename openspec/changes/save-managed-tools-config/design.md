# Design: Save Managed Tools to Config

## Overview

在 setup 命令执行后，将用户选择的 managed_tools 持久化到 GlobalConfig，并在 config ls 和 list 命令中使用该配置。

## Architecture

### 1. setup 命令保存 managed_tools

在 `run_setup` 函数中，确定 `managed_tools` 后，将其保存到 GlobalConfig：

```moonbit
// 在 run_setup 中，确定 managed_tools 后
let managed_tools_str = managed_tools.map(t => t.to_string()).join(",")
let (_, existing_config) = @tools.get_global_config()
let new_config = @tools.make_global_config(
  existing_config~,
  managed_tools=Some(managed_tools_str),
)
@tools.save_global_config(new_config)
```

### 2. config ls 显示 managed_tools

在 `run_config` 函数中，增加 managed_tools 的显示：

```moonbit
// 在 run_config() 末尾增加
print_to(result, @i18n.t("config.managed_tools"))
match config.managed_tools {
  Some(str) =>
    print_to(result, @i18n.t("config.list_key", args={ "key": "managed_tools", "value": str }))
  None =>
    print_to(result, @i18n.t("config.list_key", args={ "key": "managed_tools", "value": @i18n.t("config.managed_tools_all") }))
}
```

### 3. list 命令过滤

在 `run_list` 中，当没有指定具体 tool 时，使用 `get_managed_tools` 获取被管理的工具列表：

```moonbit
let tools = if tool is Some(tool) {
  [tool]
} else {
  let (_, global_config) = @tools.get_global_config()
  @tools.get_managed_tools(global_config)
}
```

### 4. setup 启动时自动选中之前保存的工具

当用户再次运行 setup 时，从 config.json 读取之前保存的 managed_tools，在 TUI 中自动勾选这些工具。

**C 层修改**：`multi_select` 函数增加第二个参数 `preselected`（逗号分隔的预选中项）：

```c
char* multi_select(const char* input, const char* preselected) {
    // ... 解析 input 构建 items
    // 解析 preselected，将匹配的 item 标记为 checked=1
    if (preselected && strlen(preselected) > 0) {
        char* pre_copy = strdup(preselected);
        char* pre_token = strtok(pre_copy, ",");
        while (pre_token) {
            for (int i = 0; i < count; i++) {
                if (strcmp(items[i].text, pre_token) == 0) {
                    items[i].checked = 1;
                    break;
                }
            }
            pre_token = strtok(NULL, ",");
        }
        free(pre_copy);
    }
    // ... 继续原有逻辑
}
```

**MoonBit 层修改**：

```moonbit
// print.mbt - 更新 FFI 签名
extern "C" fn c_interactive_select_tools(tools_json : Bytes, preselected : Bytes) -> String = "interactive_select_tools_c"

// setup.mbt - 调用时传入之前保存的工具
let (_, global_config) = @tools.get_global_config()
let preselected = global_config.managed_tools.unwrap_or("")
let selected_str = @stdio.interactive_select_tools_c(tools_str, preselected)
```

## i18n Keys

新增以下 i18n key：
- `config.managed_tools`: "被管理的工具" / "Managed Tools"
- `config.managed_tools_all`: "所有工具（默认）" / "All tools (default)"

## Files to Modify

| File | Change |
|------|--------|
| `cmd/command/setup.mbt` | 保存 managed_tools 到 GlobalConfig |
| `cmd/command/config.mbt` | 显示 managed_tools 配置项 |
| `cmd/command/list.mbt` | 使用 managed_tools 过滤工具列表 |
| `i18n/zh.mbt` | 新增中文文案 |
| `i18n/en.mbt` | 新增英文文案 |