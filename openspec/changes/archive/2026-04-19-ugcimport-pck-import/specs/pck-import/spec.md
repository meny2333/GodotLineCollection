## ADDED Requirements

### Requirement: Plugin copies verified PCK to pck_levels directory
插件 SHALL 将验证通过的 PCK 文件复制到 `res://pck_levels/` 目录。

#### Scenario: Import verified PCK
- **WHEN** 用户确认导入且 PCK 已通过验证
- **THEN** PCK 文件被复制到 `res://pck_levels/<filename>.pck`，并显示成功提示

#### Scenario: Import unverified PCK
- **WHEN** 用户尝试导入未通过验证的 PCK
- **THEN** 该 PCK 不被复制，提示用户验证未通过

### Requirement: Plugin warns on duplicate PCK name
插件 SHALL 在导入前检查 `res://pck_levels/` 目录下是否已存在同名 PCK 文件。

#### Scenario: Duplicate PCK exists
- **WHEN** `res://pck_levels/` 下已存在同名 PCK 文件
- **THEN** 弹出确认对话框询问用户是否覆盖

#### Scenario: No duplicate
- **WHEN** 目标目录下不存在同名文件
- **THEN** 直接复制，无需确认

### Requirement: Plugin ensures pck_levels directory exists
插件 SHALL 在导入前确保 `res://pck_levels/` 目录存在。

#### Scenario: Directory does not exist
- **WHEN** `res://pck_levels/` 目录不存在
- **THEN** 自动创建该目录后再进行复制

#### Scenario: Directory exists
- **WHEN** `res://pck_levels/` 目录已存在
- **THEN** 直接进行复制
