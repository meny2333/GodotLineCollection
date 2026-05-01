## CustomGameUI.gd — 复活 UI 组件
## 由 GameUIHook 注入到 gameui 节点
## 复制原版 gameui 的复活逻辑，无倒计时
extends Control

## 状态追踪
var _was_dead: bool = false
var _shown: bool = false

## 节点引用
@onready var _revive_panel: PanelContainer = $RevivePanel
@onready var _revive_btn: Button = $RevivePanel/ReviveVBox/ReviveBtn
@onready var _back_btn: Button = $RevivePanel/ReviveVBox/BackBtn

func _ready() -> void:
	print("[CustomGameUI] 已初始化")
	
	# 连接信号
	_revive_btn.pressed.connect(_on_revive_pressed)
	_back_btn.pressed.connect(_on_back_pressed)
	
	# 默认隐藏
	_revive_panel.visible = false


func _process(_delta: float) -> void:
	# 非侵入检测：轮询 LevelManager 的游戏状态
	var current_state = LevelManager.game_state
	var is_dead = (current_state == LevelManager.GameStatus.Died)
	
	# 死亡状态进入
	if is_dead and not _was_dead:
		_show_revive()
	
	# 复活状态离开（从 Died 变为其他状态）
	if not is_dead and _was_dead:
		_hide_revive()
	
	_was_dead = is_dead


## 显示复活 UI（无倒计时，直接可用）
func _show_revive() -> void:
	if _shown:
		return
	_shown = true
	_revive_panel.visible = true
	_revive_btn.disabled = false  # 直接可用，无倒计时
	print("[CustomGameUI] 显示复活面板")


## 隐藏复活 UI
func _hide_revive() -> void:
	_shown = false
	_revive_panel.visible = false


## 复活按钮（复制原版 gameui 逻辑）
func _on_revive_pressed() -> void:
	_hide_revive()
	
	if Player.instance.is_end:
		# 关卡结束 → 重玩
		_on_gamereplay_pressed()
	elif LevelManager.current_checkpoint:
		# 有检查点 → 在检查点复活
		LevelManager.current_checkpoint.revive()
		if LevelManager.crown > 0:
			LevelManager.is_relive = true
	else:
		# 无检查点 → 重玩
		_on_gamereplay_pressed()


## 返回按钮
func _on_back_pressed() -> void:
	get_tree().quit()
	LevelManager.is_end = false
	LevelManager.is_relive = false
	LevelManager.camera_checkpoint.restore_pending = false
	LevelManager.diamond = 0
	LevelManager.crown = 0
	LevelManager.percent = 0


## 重玩关卡
func _on_gamereplay_pressed() -> void:
	if Player.instance:
		Player.instance.reload()
	LevelManager.reset_to_defaults()
