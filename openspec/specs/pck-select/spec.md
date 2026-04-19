## ADDED Requirements

### Requirement: User can select PCK files via file dialog
插件 SHALL 提供一个 FileDialog 允许用户选择一个或多个 .pck 文件。

#### Scenario: Single PCK selection
- **WHEN** 用户点击"选择 PCK"按钮
- **THEN** 弹出 FileDialog，文件过滤器为 *.pck，允许多选

#### Scenario: Multiple PCK selection
- **WHEN** 用户在 FileDialog 中选择多个 .pck 文件并确认
- **THEN** 所有选中的 PCK 文件路径被添加到导入列表中

#### Scenario: Cancel selection
- **WHEN** 用户取消 FileDialog
- **THEN** 导入列表不变，对话框关闭
