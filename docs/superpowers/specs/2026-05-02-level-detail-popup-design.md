# Level Detail Popup 设计文档

## 概述

在LevelManager中增强"详细信息"按钮功能，从PCK导入时提取author字段，并在点击时弹出Popup显示关卡详细信息（封面、名称、作者、描述）。

## 数据层变更

### MenuLevelData.gd

新增两个字段：

```gdscript
@export var author: String = ""
@export var description: String = ""
```

- `author`：从PCK的LevelData.tres中自动提取
- `description`：用户手动填写的关卡描述

## PCK导入变更

### ugc_import/plugin.gd

#### 1. 提取author字段

在 `_find_level_data_in_pck()` 方法中：
- 读取LevelData.tres文件内容
- 解析author字段（类似现有saveID的提取方式）
- 将author存入level_info字典

#### 2. 保存author到MenuLevelData

在 `_upsert_level_list()` 方法中：
- 从level_info读取author
- 写入MenuLevelData的author字段

#### 3. 编辑对话框新增字段

在编辑对话框中新增：
- author输入框（LineEdit）
- description输入框（LineEdit或多行TextEdit）

## UI层变更

### LevelManager.gd

#### 修改 `_on_info_button()` 方法

废除原来在info_label显示文本的方式，改为弹出Popup：

```
Popup (AcceptDialog)
├── HBoxContainer
│   ├── TextureRect (左侧：封面图片)
│   └── VBoxContainer (右侧)
│       ├── Label (标题：关卡名称，大字)
│       ├── Label (副标题1：author，灰色小字)
│       └── Label (副标题2：description，灰色小字)
```

#### 实现细节

1. 创建AcceptDialog作为popup
2. 设置popup标题为"关卡详情"
3. 左侧TextureRect：
   - 设置expand_mode为EXPAND_IGNORE_SIZE
   - 设置stretch_mode为STRETCH_KEEP_ASPECT_CENTERED
   - 设置自定义最小尺寸（如200x200）
4. 右侧VBox：
   - 标题Label：font_size=24，白色
   - author Label：font_size=14，灰色
   - description Label：font_size=14，灰色，autowrap

## 文件清单

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `Scripts/MenuLevelData.gd` | 修改 | 新增author、description字段 |
| `addons/ugc_import/plugin.gd` | 修改 | 提取author、编辑对话框新增字段 |
| `Scripts/LevelManager.gd` | 修改 | 实现popup弹出逻辑 |

## 不变部分

- `Scenes/LevelManager.tscn`：无需修改，popup在代码中动态创建
- `Scripts/MenuLevelList.gd`：无需修改
- `pck_levels/level_list.tres`：导入时自动更新
