extends Node
# Autoload "Updater" (first in the list): keeps the game up to date on every platform. Each release attaches the
# game as a patch pack (Dragon-Legend.pck for Windows/Linux, -mac.pck and -android.pck with their texture formats). On the title screen the game
# asks GitHub for the latest release; if it is newer, the pack downloads in the background and the player is told
# to restart. At start-up, before any other game script loads, the newest downloaded pack is mounted over the
# built-in game (only if it was built for this exact engine version).

signal status(text: String, ready: bool)

const REPO := "laibaminhvuong-ux/dragon-legend"
const DIR := "user://updates"
var built_version := ""
var loaded_version := ""   # the patch running now, "" for the built-in game
var latest := ""
var _http: HTTPRequest
var _checked := false

func _init() -> void:
	built_version = str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	var meta := DIR + "/current.json"
	if not FileAccess.file_exists(meta):
		return
	var m: Variant = JSON.parse_string(FileAccess.get_file_as_string(meta))
	if not (m is Dictionary) or str(m.get("engine", "")) != _engine() or not newer(str(m.get("version", "")), built_version):
		return
	var file := str(m.get("file", ""))
	if FileAccess.file_exists(file) and ProjectSettings.load_resource_pack(file, true):
		loaded_version = str(m.version)

func version() -> String:
	return loaded_version if loaded_version != "" else built_version

static func _engine() -> String:
	return str(Engine.get_version_info().get("string", ""))

## "0.0.10" > "0.0.9"; a leading "v" is ignored.
static func newer(a: String, b: String) -> bool:
	var pa := a.trim_prefix("v").split(".")
	var pb := b.trim_prefix("v").split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return x > y
	return false

## Looks for a newer release once per run (title screen). Quietly does nothing offline or without releases.
func check() -> void:
	if _checked or OS.has_feature("editor") or DisplayServer.get_name() == "headless":
		return
	_checked = true
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_release)
	_http.request("https://api.github.com/repos/%s/releases/latest" % REPO, ["Accept: application/vnd.github+json", "User-Agent: DragonLegend"])

func _on_release(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var r: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (r is Dictionary):
		return
	latest = str(r.get("tag_name", "")).trim_prefix("v")
	if latest == "" or not newer(latest, version()):
		return
	var want := "Dragon-Legend-android.pck" if OS.has_feature("android") else ("Dragon-Legend-mac.pck" if OS.has_feature("macos") else "Dragon-Legend.pck")
	for a: Dictionary in r.get("assets", []):
		if str(a.get("name", "")) == want:
			_download(str(a.get("browser_download_url", "")), int(a.get("size", 0)))
			return

func _download(url: String, size: int) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var path := "%s/%s.pck" % [DIR, latest]
	status.emit("Downloading update v%s…" % latest, false)
	var dl := HTTPRequest.new()
	add_child(dl)
	dl.download_file = path + ".part"
	dl.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
		dl.queue_free()
		var ok := result == HTTPRequest.RESULT_SUCCESS and code == 200 and FileAccess.file_exists(path + ".part")
		if ok and size > 0:
			ok = FileAccess.get_file_as_bytes(path + ".part").size() == size
		if not ok:
			DirAccess.remove_absolute(path + ".part")
			status.emit("The update couldn't download. It will try again next time.", false)
			return
		DirAccess.rename_absolute(path + ".part", path)
		var f := FileAccess.open(DIR + "/current.json", FileAccess.WRITE)
		f.store_string(JSON.stringify({"version": latest, "file": path, "engine": _engine()}))
		f.close()
		status.emit("Update v%s is ready. Restart the game to play it." % latest, true))
	dl.request(url)

func restart() -> void:
	OS.set_restart_on_exit(true)
	get_tree().quit()
