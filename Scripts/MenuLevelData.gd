@tool
class_name MenuLevelData
extends Resource

@export var cover: Texture2D
@export var music: AudioStream
@export var pck_path: String = ""

@export var title: String = ""
@export var author: String = ""
@export var description: String = ""
@export var scene_path: String = ""
@export var save_id: String = ""

## 音乐开始播放时间（秒）
@export var music_start: float = 0.0
## 音乐播放持续时长（秒），0表示播放到结尾
@export var music_duration: float = 0.0
## 音乐淡入时长（秒）
@export var music_fade_in: float = 1.0
## 音乐淡出时长（秒）
@export var music_fade_out: float = 1.0
