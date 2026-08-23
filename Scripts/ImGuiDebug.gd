## ImGuiDebug.gd — Autoload 单例
## F11 切换 ImGui 显示/隐藏，提供 PopupToast 测试按钮
## 后端已迁移到 dear-imgui-godot（GDExtension / imgui-rs），autoload 名为 ImGui
extends Node

var _visible: bool = true


func _ready() -> void:
	# 监听 F11 按键
	set_process_input(true)

	# 通过 ImGui 单例注册渲染回调（dear-imgui-godot 官方方式）
	if ImGui != null and ImGui.has_signal("imgui_layout"):
		ImGui.imgui_layout.connect(_on_imgui_layout)
		print("[ImGuiDebug] 已连接 ImGui.imgui_layout，按 F11 切换显示")
	else:
		push_warning("[ImGuiDebug] 无法连接 ImGui 渲染回调")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		_toggle_visibility()
		# 不消费事件，允许其他节点继续处理


func _toggle_visibility() -> void:
	_visible = not _visible
	print("[ImGuiDebug] ImGui %s" % ("显示" if _visible else "隐藏"))


func _on_imgui_layout() -> void:
	if not _visible:
		return

	# 注意：ImGui 默认字体仅含 ASCII，面板文本使用英文
	if ImGui.begin("Imgui"):
		if ImGui.button("TestToast", 0.0, 0.0):
			PopupToast.show("Hello, GodotLine!")

	ImGui.end()
