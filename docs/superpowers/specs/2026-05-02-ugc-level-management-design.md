# UGC关卡管理增删功能设计文档

## 概述

在现有ugc_import插件中添加关卡管理功能，支持删除、编辑、排序和批量操作。

## 功能需求

### 核心功能
1. **删除已导入的关卡** - 同时删除PCK文件和level_list.tres条目
2. **编辑关卡信息** - 修改标题、封面、音乐、保存ID
3. **重新排序关卡** - 调整关卡在列表中的显示顺序
4. **批量管理** - 支持多选删除、批量导入

## 架构设计

### 界面布局
在现有ugc_import插件对话框中使用TabContainer组织功能：
- **导入标签页** - 保留现有导入功能
- **管理标签页** - 新增管理功能

### 数据存储
- **level_list.tres** - MenuLevelList资源，存储关卡元数据
- **pck_levels/*.pck** - 关卡PCK文件

## 详细功能设计

### 1. 关卡列表显示
- 从`res://pck_levels/level_list.tres`读取已导入关卡
- 显示关卡标题、PCK文件名、验证状态
- 支持多选操作（Ctrl+点击或复选框）

### 2. 删除功能
- **单选删除**：选中关卡后点击删除按钮
- **批量删除**：多选后点击删除按钮
- **删除确认**：弹出确认对话框显示将删除的文件列表
- **删除内容**：同时删除pck_levels目录中的.pck文件和level_list.tres中的条目

### 3. 编辑功能
- **编辑对话框**：点击编辑按钮打开
- **可编辑属性**：
  - 关卡标题（LineEdit）
  - 封面图片（TextureRect + FileDialog）
  - 背景音乐（AudioStreamPlayer + FileDialog）
  - 保存ID（LineEdit）
- **保存修改**：更新level_list.tres中的MenuLevelData资源

### 4. 排序功能
- **上移/下移按钮**：调整选中关卡的顺序
- **保存顺序**：更新level_list.tres中的levels数组顺序

### 5. 批量操作
- **多选模式**：ItemList支持多选
- **批量删除**：选中多个关卡后删除
- **批量导入**：保留现有功能

## 数据流

1. **读取**：从level_list.tres加载关卡列表
2. **显示**：在管理标签页显示关卡信息
3. **编辑**：修改MenuLevelData资源属性
4. **保存**：更新level_list.tres文件
5. **删除**：删除PCK文件和level_list.tres条目

## 接口设计

### 新增函数

```gdscript
# 管理标签页相关
func _create_manage_tab() -> void
func _refresh_manage_list() -> void
func _load_level_list() -> MenuLevelList
func _save_level_list(list: MenuLevelList) -> void

# 删除功能
func _on_delete_selected() -> void
func _delete_level(level: MenuLevelData) -> bool

# 编辑功能
func _on_edit_selected() -> void
func _show_edit_dialog(level: MenuLevelData) -> void
func _save_level_changes(level: MenuLevelData, changes: Dictionary) -> void

# 排序功能
func _on_move_up() -> void
func _on_move_down() -> void
func _swap_levels(index1: int, index2: int) -> void

# 批量操作
func _on_batch_delete() -> void
func _get_selected_levels() -> Array[MenuLevelData]
```

### 界面组件

- **管理标签页**：VBoxContainer包含ItemList和按钮
- **编辑对话框**：ConfirmationDialog包含表单
- **删除确认**：ConfirmationDialog

## 错误处理

- **文件不存在**：提示用户文件缺失
- **删除失败**：提示删除错误
- **保存失败**：提示保存错误

## 依赖关系

- 复用现有PCK验证逻辑（PCKDirAccess）
- 使用MenuLevelData和MenuLevelList资源类
- 使用DirAccess进行文件操作
- 使用ResourceSaver保存资源

## 实现步骤

1. 重构现有对话框，添加TabContainer
2. 创建管理标签页UI
3. 实现关卡列表显示
4. 实现删除功能
5. 实现编辑功能
6. 实现排序功能
7. 实现批量操作
8. 测试和调试
