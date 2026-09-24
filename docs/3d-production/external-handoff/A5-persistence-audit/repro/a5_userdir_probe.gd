extends SceneTree
## 只读探针：打印本次进程 user:// 的实际落点，用于验证 HOME 覆盖是否重定向隔离。
func _initialize() -> void:
	print("A5_USERDIR ", ProjectSettings.globalize_path("user://"))
	print("A5_HOME_ENV ", OS.get_environment("HOME"))
	quit(0)
