## Why

当前的 ugc_import 插件负责从外部目录扫描 LevelData、复制关卡文件及模板资源、并可选地打包为 PCK。随着 Godot 编辑器自带"导出选中场景（包含依赖项）"功能可以生成 PCK，插件中冗余的目录扫描、文件复制和 PCKPacker 打包逻辑可以移除。插件应简化为仅验证 PCK 可运行并导入到项目中。

## What Changes

- **移除**目录扫描和 LevelData .tres 检测逻辑
- **移除**从源目录复制关卡文件和模板资源的逻辑（`_import_level`、`_copy_directory_recursive`、`_import_missing_template_resources` 等系列函数）
- **移除** PCKPacker 打包逻辑（`_pack_to_pck`、`_add_template_resources`、`_pack_external_resources`、`_pack_imported_cache`、`_add_dir_to_pck`）
- **移除**"同时打包为 .pck 文件"复选框
- **新增** PCK 文件选择功能（通过 FileDialog 选择 .pck 文件）
- **新增** PCK 验证功能：加载 PCK 并检查是否包含有效的 LevelData 资源或关卡场景
- **新增** PCK 导入功能：将选中的 PCK 文件复制到 `res://pck_levels/` 目录

## Capabilities

### New Capabilities
- `pck-select`: 用户通过文件对话框选择一个或多个 .pck 文件
- `pck-verify`: 验证选中的 PCK 文件可被 Godot 加载并包含有效关卡内容
- `pck-import`: 将验证通过的 PCK 文件导入到项目的 pck_levels 目录

### Modified Capabilities

## Impact

- `addons/ugc_import/plugin.gd`：几乎重写，移除旧逻辑，新增 PCK 选择/验证/导入逻辑
- `addons/ugc_import/plugin.cfg`：可能更新描述文字
- 工作流变化：用户不再需要从源目录导入，而是先用 Godot 导出对话框导出场景为 PCK，再用插件验证并导入 PCK
