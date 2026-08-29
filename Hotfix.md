# Hotfix（热更新）

用远程 PCK 补丁覆盖已发布客户端资源。关卡下载仍走 `PCKDownloader`，这套只负责补丁包。

## 仓库

| 客户端 | 补丁仓 | manifest |
| --- | --- | --- |
| GodotLineCollection | https://github.com/godotline/GodotLinePatches | `main/manifest.json` |
| NewShinnline | https://github.com/godotline/ShinnlinePatches | `main/manifest.json` |

NewShinnline 用 `override.cfg` 的 `hot_update/manifest_urls` 覆盖默认地址，不要改 Collection 的默认 URL。

## 客户端流程

启动顺序：`Scenes/UpdateCheck.tscn` → GAS 登录 → 主界面。关卡选单返回主界面，不要回检查更新。

1. Autoload `HotUpdate` 只加载本地包（`res://patches`、`<exe>/patches`、`user://patches`）。
2. `UpdateCheck.tscn` 调 `check_updates()` 拉 manifest。有包则显示更新/稍后（`force` 时稍后变退出）。
3. 下载写入 `user://patches/`，**当场不** `load_resource_pack`。下次启动步骤 1 才加载。
4. `replace: true` 覆盖已有 `res://` 资源。`false` 只加新文件。

项目设置可改：

- `hot_update/manifest_urls`：`PackedStringArray`，按顺序尝试
- `hot_update/search_dirs`：额外本地目录

## manifest

```json
{
  "base_url": "https://raw.githubusercontent.com/godotline/GodotLinePatches/main/",
  "force": false,
  "packs": [
    {
      "filename": "example.pck",
      "replace": true,
      "force": false,
      "url": ""
    }
  ]
}
```

- `force`：顶层或单包为 true 时不能跳过。
- `url` 为空则用 `base_url + filename`。
- 已缓存在 `user://patches/` 的文件仍会列入待更新（让玩家确认），点更新会重新下载。

## 打 PCK

Godot 编辑器或脚本：

```gdscript
var packer := PCKPacker.new()
packer.pck_start("/tmp/example.pck")
packer.add_file("res://path/in/game.tscn", "/abs/path/to/source.tscn")
packer.flush(true)
```

`add_file` 的第一个参数是游戏内路径，必须和要覆盖的 `res://` 一致。UID 不要和工程里现有场景撞车——补丁源文件不要提交进游戏仓。

## 坑

- GDScript 闭包按值捕获 `bool`。下载循环的 `done` 必须放进 `Dictionary`，否则进度到 100% 会卡死（FPS≈1）。
- 下载完成后不要在当前帧 `load_resource_pack` 再立刻 `change_scene`，会卡住。只写盘，下次启动加载。
- 不要把 hotfix 场景放进 `res://patches/` 当主场景打开；UID 冲突会让编辑器打开补丁而不是原场景。
- 编辑器 `user://` 在 `~/.local/share/godot/app_userdata/<项目名>/patches/`。测弹窗前可删这里的旧 pck。
- `HTTPRequest` 必须进场景树；进度用 `get_downloaded_bytes()` / `get_body_size()` 每帧刷。

## 测一次

1. 往对应补丁仓推一个 `replace: true` 的 pck + manifest。
2. 删掉 `user://patches/` 里同名文件。
3. 运行游戏（走正常主场景，不要单独跑补丁 tscn）。
4. 应弹出更新；点更新有进度；结束后进主界面。
5. 再开一次游戏，补丁生效（覆盖的场景/脚本已变）。
