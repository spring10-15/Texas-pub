extends RefCounted
## Versioned local checkpoints. Decoding never permits serialized objects.
const VERSION := 1

static func write_checkpoint(path: String, state: Dictionary) -> Error:
	var bytes := var_to_bytes(state)
	var envelope := {"version": VERSION, "digest": bytes.hex_encode().sha256_text(), "payload": bytes}
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_var(envelope, false)
	file.flush()
	var result := file.get_error()
	file.close()
	if result != OK:
		return result
	# Verify the complete temporary file before replacing the last usable checkpoint.
	if read_checkpoint(temporary).get("status") != "ok":
		return ERR_FILE_CORRUPT
	return DirAccess.rename_absolute(temporary, path)

static func read_checkpoint(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"status": "missing"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"status": "unreadable"}
	if file.get_length() < 4 or file.get_32() > file.get_length() - 4:
		file.close()
		return {"status": "invalid"}
	file.seek(0)
	var envelope: Variant = file.get_var(false)
	file.close()
	if not envelope is Dictionary:
		return {"status": "invalid"}
	var stored_version: Variant = envelope.get("version")
	if not stored_version is int:
		return {"status": "invalid"}
	if stored_version != VERSION:
		return {"status": "unsupported_version", "version": stored_version}
	var payload: Variant = envelope.get("payload")
	if not payload is PackedByteArray or envelope.get("digest") != payload.hex_encode().sha256_text():
		return {"status": "invalid"}
	var state: Variant = bytes_to_var(payload)
	if not state is Dictionary:
		return {"status": "invalid"}
	return {"status": "ok", "state": state}
