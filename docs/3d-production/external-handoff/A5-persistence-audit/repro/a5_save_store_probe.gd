extends SceneTree
## A5 诊断探针：save_store.gd 文件层语义。
## 只在 --tmp 指定的隔离临时目录内读写；不触碰 user:// 正式槽位。
## 用法：godot --headless --script <本文件绝对路径> -- --test --tmp=<隔离临时目录绝对路径>
const Store = preload("res://three_d/rules/save_store.gd")
var failures: Array[String] = []
var cases := {}
var tmp := ""

func note(case_id: String, data: Dictionary) -> void:
	cases[case_id] = data
	print("A5_CASE ", JSON.stringify({"case": case_id, "data": data}))

func verify(case_id: String, ok: bool, detail: String) -> void:
	if not ok:
		failures.append(case_id + ": " + detail)
		push_error("A5 PROBE FAIL " + case_id + ": " + detail)

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tmp="):
			tmp = argument.trim_prefix("--tmp=")
	if tmp.is_empty() or not tmp.begins_with("/"):
		push_error("A5 probe requires --tmp=<absolute isolated dir>")
		quit(1)
		return
	var directory := DirAccess.open(tmp)
	if directory == null:
		push_error("A5 probe tmp dir not openable: " + tmp)
		quit(1)
		return
	run_probe()
	var summary := {"cases": cases, "checks": cases.size(), "failures": failures, "failed": failures.size()}
	print("A5_SAVE_STORE_PROBE ", JSON.stringify(summary))
	quit(0 if failures.is_empty() else 1)

func fresh(name: String) -> String:
	var path := tmp.path_join(name)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".tmp")
	return path

func craft_envelope(path: String, envelope: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_var(envelope)
	file.close()

func run_probe() -> void:
	# 1) 空档
	var missing_path := fresh("missing.save")
	var missing: Dictionary = Store.read_checkpoint(missing_path)
	note("read_missing", {"status": missing.status, "file_exists": FileAccess.file_exists(missing_path)})
	verify("read_missing", missing.status == "missing" and not FileAccess.file_exists(missing_path), "expected missing")

	# 2) 首次写入 + 读回
	var path := fresh("valid.save")
	var state := {"cash": 240, "active": true, "cards": [{"rank": 14, "suit": "S"}], "position": Vector3(1, 2, 3)}
	var write_new := Store.write_checkpoint(path, state)
	var loaded: Dictionary = Store.read_checkpoint(path)
	note("write_new+read_valid", {"error": write_new, "status": loaded.status, "state_equal": loaded.get("state") == state, "tmp_left": FileAccess.file_exists(path + ".tmp")})
	verify("write_new", write_new == OK and loaded.status == "ok" and loaded.get("state") == state and not FileAccess.file_exists(path + ".tmp"), "new write")

	# 3) 原子替换
	state.cash = 180
	var write_replace := Store.write_checkpoint(path, state)
	loaded = Store.read_checkpoint(path)
	note("write_replace", {"error": write_replace, "status": loaded.status, "state_equal": loaded.get("state") == state, "tmp_left": FileAccess.file_exists(path + ".tmp")})
	verify("write_replace", write_replace == OK and loaded.status == "ok" and loaded.get("state") == state and not FileAccess.file_exists(path + ".tmp"), "replace")

	# 4) 摘要损坏（payload 被改，digest 不重算）
	var envelope: Dictionary = FileAccess.open(path, FileAccess.READ).get_var(false)
	var digest_before: String = str(envelope.digest)
	envelope.payload[0] = (envelope.payload[0] + 1) % 256
	craft_envelope(path, envelope)
	var corrupt := Store.read_checkpoint(path)
	note("digest_broken", {"status": corrupt.status, "digest_unchanged": envelope.digest == digest_before})
	verify("digest_broken", corrupt.status == "invalid", "expected invalid")

	# 5) 版本不支持（payload/digest 完全合法，仅 version 非 1）
	var version_only := fresh("version.save")
	var good_payload: PackedByteArray = var_to_bytes({"cash": 1})
	var version_envelope := {"version": 99, "digest": good_payload.hex_encode().sha256_text(), "payload": good_payload}
	craft_envelope(version_only, version_envelope)
	var version_status: String = Store.read_checkpoint(version_only).status
	# 5b) 版本不支持且缺 payload（现有测试用的形态）
	var version_nopayload := fresh("version_nopayload.save")
	craft_envelope(version_nopayload, {"version": 99})
	var version_nopayload_status: String = Store.read_checkpoint(version_nopayload).status
	note("version_unsupported", {"status_valid_payload": version_status, "status_missing_payload": version_nopayload_status,
		"distinguishable_from_digest": version_status != corrupt.status})
	verify("version_unsupported", version_status == "invalid" and version_nopayload_status == "invalid", "expected invalid")

	# 6) payload 解码为非 Dictionary（Array）
	var array_payload := fresh("array.save")
	var array_bytes: PackedByteArray = var_to_bytes([1, 2, 3])
	craft_envelope(array_payload, {"version": 1, "digest": array_bytes.hex_encode().sha256_text(), "payload": array_bytes})
	var array_decoded = bytes_to_var(array_bytes)
	var array_status: String = Store.read_checkpoint(array_payload).status
	note("payload_not_dictionary", {"decoded_type": type_string(typeof(array_decoded)), "status": array_status})
	verify("payload_not_dictionary", array_status == "invalid", "expected invalid")

	# 7) 含对象/资源的 payload 是否真被拒（不凭注释推断）
	var node := Node.new()
	var object_bytes: PackedByteArray = var_to_bytes_with_objects({"node": node})
	var object_decoded = bytes_to_var(object_bytes)
	note("bytes_to_var_object_semantics", {"payload_size": object_bytes.size(), "decoded_type": type_string(typeof(object_decoded)),
		"decoded_is_dictionary": object_decoded is Dictionary})
	var object_path := fresh("object.save")
	craft_envelope(object_path, {"version": 1, "digest": object_bytes.hex_encode().sha256_text(), "payload": object_bytes})
	var object_status: String = Store.read_checkpoint(object_path).status
	note("object_payload", {"status": object_status})
	verify("object_payload", object_status == "invalid", "object payload must not decode to a Dictionary")
	# 7b) var_to_bytes（不带 objects）对含对象状态做了什么是静默降级还是报错
	var plain_bytes: PackedByteArray = var_to_bytes({"node": node})
	var plain_decoded = bytes_to_var(plain_bytes)
	var plain_node_type := "n/a"
	if plain_decoded is Dictionary:
		plain_node_type = type_string(typeof(plain_decoded.get("node")))
	var object_state_path := fresh("object_state.save")
	var object_write := Store.write_checkpoint(object_state_path, {"node": node})
	var object_state_read := Store.read_checkpoint(object_state_path)
	note("write_object_state", {"write_error": object_write, "read_status": object_state_read.status,
		"plain_var_to_bytes_size": plain_bytes.size(), "plain_bytes_decoded_node_type": plain_node_type,
		"plain_roundtrip_is_dictionary": plain_decoded is Dictionary})
	node.free()
	var resource := Resource.new()
	var resource_bytes: PackedByteArray = var_to_bytes_with_objects({"resource": resource})
	var resource_path := fresh("resource.save")
	craft_envelope(resource_path, {"version": 1, "digest": resource_bytes.hex_encode().sha256_text(), "payload": resource_bytes})
	note("resource_payload", {"status": Store.read_checkpoint(resource_path).status})

	# 8) 截断
	var trunc_path := fresh("truncate.save")
	Store.write_checkpoint(trunc_path, state)
	var complete: PackedByteArray = FileAccess.get_file_as_bytes(trunc_path)
	var handle := FileAccess.open(trunc_path, FileAccess.WRITE)
	handle.store_buffer(complete.slice(0, complete.size() / 2))
	handle.close()
	note("truncated", {"status": Store.read_checkpoint(trunc_path).status})
	verify("truncated", Store.read_checkpoint(trunc_path).status == "invalid", "expected invalid")

	# 9) 手工伪造长度前缀越界（文件不足 4 字节 / 前缀大于余长）
	var short_path := fresh("short.save")
	handle = FileAccess.open(short_path, FileAccess.WRITE)
	handle.store_buffer(PackedByteArray([1, 2, 3]))
	handle.close()
	var short_status: String = Store.read_checkpoint(short_path).status
	var prefix_path := fresh("prefix.save")
	handle = FileAccess.open(prefix_path, FileAccess.WRITE)
	handle.store_32(0xFFFFFF)
	handle.store_buffer(PackedByteArray([1, 2, 3]))
	handle.close()
	var prefix_status: String = Store.read_checkpoint(prefix_path).status
	note("length_prefix", {"lt4_status": short_status, "prefix_overflow_status": prefix_status})
	verify("length_prefix", short_status == "invalid" and prefix_status == "invalid", "expected invalid")

	# 10) 写入失败（父目录不存在 / 目标为目录）
	var absent_parent := tmp.path_join("no_such_dir").path_join("x.save")
	var absent_error := Store.write_checkpoint(absent_parent, {"cash": 1})
	var open_error := FileAccess.get_open_error()
	var dir_path := tmp.path_join("a_directory")
	DirAccess.make_dir_recursive_absolute(dir_path)
	var dir_error := Store.write_checkpoint(dir_path, {"cash": 1})
	note("write_failure", {"absent_parent_error": absent_error, "last_open_error": open_error, "dir_target_error": dir_error})
	verify("write_failure", absent_error != OK and dir_error != OK, "expected non-OK errors")

	# 11) unreadable：存在但不可打开（chmod 000）
	var locked := fresh("locked.save")
	Store.write_checkpoint(locked, state)
	var chmod_code := OS.execute("/bin/chmod", ["000", locked])
	var exists := FileAccess.file_exists(locked)
	var locked_status: String = Store.read_checkpoint(locked).status
	OS.execute("/bin/chmod", ["644", locked])
	note("unreadable", {"chmod_exit": chmod_code, "file_exists": exists, "status": locked_status,
		"reachable": locked_status == "unreadable", "chmod_locked": chmod_code == 0})
	verify("unreadable_probe_valid", chmod_code == 0 and exists and locked_status == "unreadable",
		"unreadable branch not reached (chmod_exit=%d exists=%s status=%s)" % [chmod_code, str(exists), locked_status])
