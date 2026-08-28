## ImGuiDebug.gd — Autoload 单例
## F11 切换 ImGui 显示/隐藏，提供 PopupToast 测试按钮
extends Node

var _visible: bool = true


func _ready() -> void:
	set_process_input(true)
	var imgui_gd = Engine.get_singleton("ImGuiGD")
	if imgui_gd and imgui_gd.has_method("Connect"):
		imgui_gd.Connect(_on_imgui_layout)
		print("[ImGuiDebug] ImGuiGD.Connect ok, F11 toggles")
	else:
		var imgui_root = get_node_or_null("/root/ImGuiRoot")
		if imgui_root and imgui_root.has_signal("imgui_layout"):
			imgui_root.imgui_layout.connect(_on_imgui_layout)
			print("[ImGuiDebug] ImGuiRoot.imgui_layout ok, F11 toggles")
		else:
			push_warning("[ImGuiDebug] cannot connect ImGui layout")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		_toggle_visibility()


func _toggle_visibility() -> void:
	var imgui_gd = Engine.get_singleton("ImGuiGD")
	if imgui_gd:
		_visible = not _visible
		imgui_gd.Visible = _visible
		print("[ImGuiDebug] ImGui %s" % ("on" if _visible else "off"))
		return
	var imgui_root = get_node_or_null("/root/ImGuiRoot")
	if imgui_root and imgui_root.get_child_count() > 0:
		var layer = imgui_root.get_child(0)
		if layer is CanvasLayer:
			_visible = not _visible
			layer.visible = _visible
			print("[ImGuiDebug] ImGui %s (fallback)" % ("on" if _visible else "off"))


func _on_imgui_layout() -> void:
	if not _visible:
		return
	if ImGui.Begin("Imgui"):
		if ImGui.Button("TestToast"):
			PopupToast.show("Hello, GodotLine!")
	ImGui.End()
