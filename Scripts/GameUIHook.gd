## GameUIHook.gd — Autoload 单例
## 替换模式：检测 gameui 节点，用自定义 UI 完全替换它
## 不修改 #Template 中的任何文件
extends Node

## 替换后的 UI 实例引用
var _replacement_ui: Control = null

## 目标节点名（与 GAMEUI.tscn 根节点名一致）
const TARGET_NODE_NAME := "gameui"

## 自定义 UI 场景路径（可选，也可以用代码创建）
const CUSTOM_UI_SCENE := "res://Scenes/CustomGameUI.tscn"

func _ready() -> void:
	# 监听节点添加事件
	get_tree().node_added.connect(_on_node_added)
	print("[GameUIHook] 已启动，监听 gameui 节点...")


func _on_node_added(node: Node) -> void:
	# 检测目标节点
	if node.name == TARGET_NODE_NAME and node is Control:
		# 延迟一帧确保节点完全初始化
		_replace_deferred.call_deferred(node)


func _replace_deferred(gameui: Control) -> void:
	# 避免重复替换
	if _replacement_ui and is_instance_valid(_replacement_ui):
		print("[GameUIHook] 已替换，跳过")
		return
	
	print("[GameUIHook] 检测到 gameui: ", gameui.get_path())
	
	# 记录父节点和位置索引
	var parent := gameui.get_parent()
	var child_index := gameui.get_index()
	
	if not parent:
		push_warning("[GameUIHook] gameui 没有父节点，无法替换")
		return
	
	# 创建替换 UI
	if ResourceLoader.exists(CUSTOM_UI_SCENE):
		_replacement_ui = load(CUSTOM_UI_SCENE).instantiate()
	else:
		_replacement_ui = _create_custom_ui_by_code()
	
	# 从父节点移除原 gameui
	parent.remove_child(gameui)
	gameui.queue_free()
	
	# 在相同位置插入替换 UI
	parent.add_child(_replacement_ui)
	parent.move_child(_replacement_ui, child_index)
	
	print("[GameUIHook] gameui 已替换")


## 代码创建自定义 UI（当场景文件不存在时使用）
func _create_custom_ui_by_code() -> Control:
	var container := VBoxContainer.new()
	container.name = "CustomGameUI"
	container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	container.position = Vector2(10, 10)
	
	var btn := Button.new()
	btn.name = "LevelListBtn"
	btn.text = "关卡列表"
	btn.pressed.connect(_on_level_list_pressed)
	container.add_child(btn)
	
	return container


func _on_level_list_pressed() -> void:
	print("[GameUIHook] 关卡列表按钮按下")
	get_tree().change_scene_to_file("res://Scenes/LevelManager.tscn")


## 清理（场景切换时自动调用）
func _exit_tree() -> void:
	_replacement_ui = null
