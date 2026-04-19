## ADDED Requirements

### Requirement: Plugin verifies PCK can be loaded by Godot
插件 SHALL 使用 `ProjectSettings.load_resource_pack()` 尝试加载选中的 PCK 文件，验证其可被 Godot 引擎正确读取。

#### Scenario: Valid PCK loads successfully
- **WHEN** 用户选中一个格式正确且兼容的 PCK 文件
- **THEN** `load_resource_pack()` 返回 true，该 PCK 在列表中标记为"验证通过"

#### Scenario: Invalid PCK fails to load
- **WHEN** 用户选中一个损坏或版本不兼容的 PCK 文件
- **THEN** `load_resource_pack()` 返回 false，该 PCK 在列表中标记为"验证失败"，并显示错误原因

### Requirement: Plugin verifies PCK contains valid level content
插件 SHALL 在 PCK 加载后检查其中是否包含有效的关卡内容（LevelData 资源或 .tscn 场景文件）。

#### Scenario: PCK contains level data
- **WHEN** 加载的 PCK 中包含路径以 `res://levels/` 开头的 .tres 文件且可加载为 LevelData
- **THEN** 该 PCK 标记为"包含有效关卡"

#### Scenario: PCK contains level scene
- **WHEN** 加载的 PCK 中包含路径以 `res://levels/` 开头的 .tscn 场景文件
- **THEN** 该 PCK 标记为"包含有效关卡"

#### Scenario: PCK has no level content
- **WHEN** 加载的 PCK 中不包含任何关卡相关资源
- **THEN** 该 PCK 标记为"无关卡内容"，提示用户检查 PCK 内容

### Requirement: Plugin warns about PCK memory residency after verification
插件 SHALL 在验证完成后提示用户已加载的 PCK 资源驻留在内存中，需重启编辑器才能释放。

#### Scenario: Verification completes
- **WHEN** PCK 验证流程完成（无论通过或失败）
- **THEN** 在 UI 中显示提示："验证加载的 PCK 资源已驻留内存，需重启编辑器以释放"
