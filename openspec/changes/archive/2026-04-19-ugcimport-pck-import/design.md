## Context

当前 `ugc_import` 插件是一个 330 行的 EditorPlugin，负责从外部目录扫描 LevelData .tres 文件、复制关卡文件及模板资源到项目中、并可选地使用 PCKPacker 打包为 PCK。用户现在改用 Godot 编辑器自带的"导出选中场景（包含依赖项）"功能直接导出 PCK，因此插件中的文件复制和 PCK 打包逻辑已不再需要。

运行时 LevelManager 通过 `ProjectSettings.load_resource_pack()` 加载 `res://pck_levels/` 目录下的 PCK 文件，扫描 PCK 中的关卡场景。PCK 文件内部路径以 `res://levels/<name>/` 为前缀。

## Goals / Non-Goals

**Goals:**
- 简化 ugc_import 插件为 PCK 导入工具：选择 PCK → 验证可运行 → 导入到 pck_levels
- 验证逻辑确认 PCK 可被 Godot 加载且包含有效的关卡内容
- 保留与现有运行时 LevelManager 的兼容性（PCK 放入 `res://pck_levels/`）

**Non-Goals:**
- 不再支持从源目录扫描和导入关卡
- 不再内置 PCK 打包功能（由 Godot 导出对话框完成）
- 不修改 LevelManager 的运行时逻辑
- 不修改 PCKManager 插件

## Decisions

### 1. 验证策略：使用 ProjectSettings.load_resource_pack 加载后检查资源

**选择**：在编辑器中调用 `ProjectSettings.load_resource_pack()` 加载 PCK，然后尝试加载关卡资源验证其有效性。

**理由**：这是与运行时完全一致的加载方式，能最准确地判断 PCK 是否可用。替代方案是用 PCKDirAccess 直接读取 PCK 目录结构，但那只能看到文件列表，无法验证资源是否可正确加载。

**替代方案**：仅检查 PCK 文件头/格式有效性。缺点是无法确认内容完整性。

### 2. 验证后需重启编辑器以卸载 PCK

**选择**：验证加载后提示用户 PCK 资源已驻留内存，需重启编辑器才能卸载。

**理由**：Godot 的 `load_resource_pack` 不支持卸载已加载的 PCK。这是引擎限制，无法绕过。

**替代方案**：不实际加载而是仅扫描目录结构。放弃，因为无法保证运行时可用。

### 3. UI 设计：FileDialog 选择 PCK + 验证结果列表

**选择**：使用 FileDialog 选择一个或多个 .pck 文件，在对话框的 ItemList 中显示每个 PCK 的验证状态（通过/失败），确认后将 PCK 复制到 pck_levels。

**理由**：简单直观，用户可一目了然看到哪些 PCK 可用。

### 4. PCK 导入方式：文件复制

**选择**：将选中的 PCK 文件直接复制到 `res://pck_levels/` 目录。

**理由**：与现有 LevelManager 的扫描逻辑完全兼容，无需任何运行时改动。

## Risks / Trade-offs

- **[验证加载后 PCK 驻留内存]** → 在 UI 中明确提示用户"验证后需重启编辑器以释放已加载的 PCK 资源"，验证通过后自动复制 PCK 到目标目录
- **[同名 PCK 覆盖]** → 导入前检查 pck_levels 目录下是否已存在同名文件，若存在则提示用户确认覆盖
- **[PCK 格式不兼容]** → `load_resource_pack` 返回 false 时标记验证失败，提示用户检查 PCK 版本兼容性
