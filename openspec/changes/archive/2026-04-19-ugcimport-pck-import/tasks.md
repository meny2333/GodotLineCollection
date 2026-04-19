## 1. 重构 UI：移除旧界面，创建 PCK 导入对话框

- [x] 1.1 移除旧的 UI 组件（source_path_edit、browse_button、refresh_button、level_list、pack_pck_check）及相关信号连接
- [x] 1.2 创建新的导入对话框 UI：包含 PCK 文件列表（ItemList）、选择 PCK 按钮、验证状态列、确认导入按钮
- [x] 1.3 添加 FileDialog 用于选择 .pck 文件（多选模式，文件过滤器 *.pck）

## 2. 实现 PCK 选择功能

- [x] 2.1 实现选择按钮点击后弹出 FileDialog
- [x] 2.2 用户确认选择后将 PCK 文件路径添加到 ItemList 中
- [x] 2.3 用户取消选择时对话框正常关闭，列表不变

## 3. 实现 PCK 验证功能

- [x] 3.1 实现验证逻辑：调用 `ProjectSettings.load_resource_pack()` 加载 PCK，记录返回结果
- [x] 3.2 加载成功后扫描 PCK 中是否包含 `res://levels/` 下的 LevelData .tres 或 .tscn 场景文件
- [x] 3.3 在 ItemList 中显示验证状态（通过/失败/无关卡内容）
- [x] 3.4 验证完成后显示提示："验证加载的 PCK 资源已驻留内存，需重启编辑器以释放"

## 4. 实现 PCK 导入功能

- [x] 4.1 确认导入时过滤掉未通过验证的 PCK，仅复制验证通过的 PCK
- [x] 4.2 导入前检查 `res://pck_levels/` 目录是否存在同名 PCK，存在则弹出覆盖确认对话框
- [x] 4.3 确保导入前创建 `res://pck_levels/` 目录（如不存在）
- [x] 4.4 复制 PCK 文件到 `res://pck_levels/` 并显示成功/失败提示

## 5. 清理旧代码

- [x] 5.1 移除所有旧导入逻辑函数（_scan_for_level_data、_import_level、_copy_directory_recursive、_import_missing_template_resources、_copy_missing_resources、_try_copy_from_source、_copy_imported_cache_files）
- [x] 5.2 移除所有旧 PCK 打包逻辑函数（_pack_to_pck、_add_template_resources、_pack_external_resources、_pack_imported_cache、_add_dir_to_pck）
- [x] 5.3 移除旧的常量（LEVELS_DIR 不再需要）
- [x] 5.4 更新 plugin.cfg 中的描述文字以反映新功能
