extends Node

## Emitted to transfer java version check data.
## [br][param status] is one of [constant JAVA_STATUS_OK], [constant JAVA_STATUS_NOT_FOUND] or
## [constant JAVA_STATUS_INVALID]. When it is not [constant JAVA_STATUS_OK], [param verstr] is empty
## and [param result] is meaningless; callers must render the "not detected" state instead of "safe".
signal java_info_transfer(status: int, verstr: String, result: bool)
## Emitted to transfer cpu instruction set check data.
signal cpu_info_transfer(avx512f: bool, avx512bw: bool, avx512vbmi: bool, bmi2: bool)
## Emitted to transfer final result.[br]
## Result is represented by an interger: 0 for safe, 1 for risk (java vulnerable but insufficient cpu
## set), 2 for danger (both vulnerable), 3 for "java not detected" (inconclusive, NOT safe).
signal final_result_transfer(result: int)

enum {
	JAVA_STATUS_OK = 0,
	## No Java at all: not on PATH, no JAVA_HOME, no common install dir, no custom path.
	JAVA_STATUS_NOT_FOUND = 1,
	## A Java path was given (or registered) but is not runnable, e.g. a stale symlink.
	JAVA_STATUS_INVALID = 2,
}

enum {
	RESULT_SAFE = 0,
	RESULT_RISK = 1,
	RESULT_DANGER = 2,
	## Java could not be detected. Deliberately not merged into [constant RESULT_SAFE]: reporting
	## green here would be a false negative on machines that ship a bundled JRE.
	RESULT_NOT_DETECTED = 3,
}

## Seconds to wait for the Python java check before giving up.
## [br]A backstop in addition to the timeout inside the Python script: PyRunner only reads the
## sub-process pipe by polling, so a hung sub-process would otherwise never emit output at all.
@export var java_check_timeout: float = 20.0

@export_file("*.py") var cpu_check_path: String
@export_file("*.py") var java_check_path: String

## Whether a Java installation was actually found and checked.
var java_installed: bool = false
var java_check_result: bool = false
var cpu_check_total_result: bool

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#PyRunner.output_received.connect(_on_output_received)
	PyRunner.error_received.connect(_on_error_received)

func _on_start_button_pressed():
	$VSplitContainer/DetectionContainer/StartupScreen.visible = false
	$VSplitContainer/DetectionContainer/DetectionScreen.visible = true
	
	if not await run_java_version_check(): return
	# CPU is still checked when Java is missing: the instruction set is a property of the
	# machine, not of the Java installation, so the report stays complete.
	if not await run_cpu_set_check(): return
	update_final_result()

## Returns whether the check ran to completion. A missing Java is a valid conclusion, so this
## still returns [code]true[/code]; only a broken or timed-out check returns [code]false[/code].
func run_java_version_check() -> bool:
	var java_path = $VSplitContainer/DetectionContainer/StartupScreen/JavaFileSelect/FileSelection.text.strip_edges()
	if java_path != "" and not FileAccess.file_exists(java_path):
		# The user explicitly picked a binary that no longer exists. Do not silently fall back to
		# a system JVM, that would report a result for something the user did not ask about.
		_emit_java_status(JAVA_STATUS_INVALID)
		return true
	print("Starting java check Python script...")
	if not _start_python_entry_point(java_check_path): return false
	print("Script started, sending path...")
	PyRunner.send_input(java_path)
	print("Path sended, waiting response...")
	var result: Dictionary = await _await_python_output(java_check_timeout)
	PyRunner.stop()
	if result.output == null:
		_on_error_received(_python_failure_reason(result, java_check_timeout))
		return false
	var java_check_raw: String = (result.output as String).strip_edges()
	print("Received raw response data")
	var status: String = java_check_raw.get_slice(" ", 0)
	match status:
		"OK":
			var jcl = java_check_raw.split(" ")
			if len(jcl) != 3:
				_on_error_received("Wrong length of java_check_list: %s" % java_check_raw)
				return false
			java_check_result = str2bool(jcl[2])
			java_installed = true
			print("Java version check done! Current version: %s, check result: %s" % [
				jcl[1], "AFFECTED" if java_check_result else "Safe"])
			java_info_transfer.emit(JAVA_STATUS_OK, jcl[1], java_check_result)
			return true
		"NOT_FOUND":
			print("Java version check done! No Java installed.")
			_emit_java_status(JAVA_STATUS_NOT_FOUND)
			return true
		"INVALID":
			var detail: String = java_check_raw.trim_prefix("INVALID").strip_edges()
			print("Java version check done! Invalid Java: %s" % detail)
			_emit_java_status(JAVA_STATUS_INVALID)
			return true
		"TIMEOUT":
			_on_error_received("Java check timed out inside the Python script.")
			return false
		"BROKEN", "ERROR":
			_on_error_received(java_check_raw.trim_prefix(status).strip_edges())
			return false
		_:
			_on_error_received("Unexpected java check response: %s" % java_check_raw)
			return false

func _emit_java_status(status: int) -> void:
	java_installed = false
	java_check_result = false
	java_info_transfer.emit(status, "", false)

func run_cpu_set_check() -> bool:
	print("Starting cpu check Python script...")
	if not _start_python_entry_point(cpu_check_path): return false
	var result: Dictionary = await _await_python_output(java_check_timeout)
	PyRunner.stop()
	if result.output == null:
		_on_error_received(_python_failure_reason(result, java_check_timeout))
		return false
	var cpu_check_raw: String = (result.output as String).strip_edges()
	if cpu_check_raw.begins_with("ERROR"):
		_on_error_received(cpu_check_raw.trim_prefix("ERROR").strip_edges())
		return false
	var ccl = cpu_check_raw.split(" ")
	if len(ccl) != 4: 
		_on_error_received("Wrong length of cpu_check_list: %s" % cpu_check_raw)
		return false
	var avx512f: bool = str2bool(ccl[0])
	var avx512bw: bool = str2bool(ccl[1])
	var avx512vbmi: bool = str2bool(ccl[2])
	var bmi2: bool = str2bool(ccl[3])
	cpu_check_total_result = avx512f and avx512bw and avx512vbmi and bmi2
	cpu_info_transfer.emit(avx512f, avx512bw, avx512vbmi, bmi2)
	return true

## Awaits the next Python output line.
## [br]Returns a Dictionary with three keys:
## [br]- [code]output[/code]: the stdout line, or [code]null[/code] when none arrived.
## [br]- [code]error[/code]: the last stderr text, or [code]null[/code]. It is only used to
##   explain a failure, never to override a valid result, because a stray warning on stderr
##   must not hide a good answer on stdout.
## [br]- [code]exited[/code]: [code]true[/code] when the interpreter died before producing any
##   output. Without this the caller would sit out the whole timeout and blame "slow" for what
##   is actually an immediate crash.
## [br]This is a backstop in addition to the timeout inside the Python script: PyRunner only
## reads the sub-process pipe by polling, so a hung or silent sub-process emits nothing at all.
func _await_python_output(timeout: float) -> Dictionary:
	var timer := get_tree().create_timer(timeout, true, false, true)
	var state := {"payload": null, "error": null}
	# A Dictionary is used rather than local variables because a lambda capturing a local
	# writes to its own copy, which would never be visible here.
	var on_output := func(data: String) -> void:
		if state.payload == null: state.payload = data
	var on_error := func(data: String) -> void:
		state.error = data
	PyRunner.output_received.connect(on_output)
	PyRunner.error_received.connect(on_error)
	# Give up when output arrives, when the deadline passes, or when the interpreter is gone.
	# Polling `active` lets a crashed interpreter fail in ~10ms instead of waiting out the timeout.
	while state.payload == null and timer.time_left > 0.0 and PyRunner.active:
		await get_tree().process_frame
	var exited: bool = state.payload == null and not PyRunner.active
	# Drop the listeners so they cannot fire into this call after it returns, and so repeated
	# runs do not pile up connections.
	if PyRunner.output_received.is_connected(on_output):
		PyRunner.output_received.disconnect(on_output)
	if PyRunner.error_received.is_connected(on_error):
		PyRunner.error_received.disconnect(on_error)
	return {"output": state.payload, "error": state.error, "exited": exited}

## Builds the message shown when a Python check produced no usable result.
func _python_failure_reason(result: Dictionary, timeout: float) -> String:
	if result.error != null:
		# The real cause, e.g. ModuleNotFoundError or a Nuitka extraction failure.
		return str(result.error)
	if result.exited:
		return "Python interpreter exited before returning a result and wrote nothing to stderr. " \
			+ "The bundled interpreter may have been blocked by antivirus, or failed to unpack."
	return "Check timed out after %s seconds." % timeout

## Starts a Python entry point and returns whether the sub-process is running.
## [br]PyRunner emits [signal SubProcess.started] synchronously inside
## [method PyRunner.start_entry_point], so awaiting it here would hang. The
## listener thread cancel flags are reset since [method SubProcess.stop] leaves
## them set, which would make the next run exit immediately.
func _start_python_entry_point(entry_point_path: String) -> bool:
	PyRunner.output_thread.set_meta('canceled', false)
	PyRunner.error_thread.set_meta('canceled', false)
	PyRunner.start_entry_point(entry_point_path)
	if not PyRunner.active:
		_on_error_received("Unable to start Python interpreter.")
		return false
	return true

func update_final_result():
	if not java_installed:
		final_result_transfer.emit(RESULT_NOT_DETECTED)
	elif not java_check_result:
		final_result_transfer.emit(RESULT_SAFE)
	elif not cpu_check_total_result:
		final_result_transfer.emit(RESULT_RISK)
	else:
		final_result_transfer.emit(RESULT_DANGER)

func str2bool(instr: String) -> bool:
	return instr.to_lower() == "true"
	
func _on_error_received(data: String) -> void:
	printerr(data)
	$ErrorPopup.visible = true
	$ErrorPopup/ErrorMargin/ErrorContainer/ErrorText/MsgBackground/ErrorMessage.text = data
