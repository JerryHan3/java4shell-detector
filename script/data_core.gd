extends Node

## Emitted to transfer java version check data.
signal java_info_transfer(verstr: String, result: bool)
## Emitted to transfer cpu instruction set check data.
signal cpu_info_transfer(avx512f: bool, avx512bw: bool, avx512vbmi: bool, bmi2: bool)
## Emitted to transfer final result.[br]
## Result is represented by an interger. 0 for safe, 1 for risk (java vulnerable but insufficient cpu set), 2 for danger (both vulnerable)
signal final_result_transfer(result: int)

@export_file("*.py") var cpu_check_path: String
@export_file("*.py") var java_check_path: String

var java_check_result: bool
var cpu_check_total_result: bool

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#PyRunner.output_received.connect(_on_output_received)
	PyRunner.error_received.connect(_on_error_received)

func _on_start_button_pressed():
	$VSplitContainer/DetectionContainer/StartupScreen.visible = false
	$VSplitContainer/DetectionContainer/DetectionScreen.visible = true
	
	if not await run_java_version_check(): return
	if not await run_cpu_set_check(): return
	update_final_result()

func run_java_version_check() -> bool:
	var java_path = $VSplitContainer/DetectionContainer/StartupScreen/JavaFileSelect/FileSelection.text
	if java_path == "": java_path = "java"
	print("Starting java check Python script...")
	if not _start_python_entry_point(java_check_path): return false
	print("Script started, sending path...")
	PyRunner.send_input(java_path)
	print("Path sended, waiting response...")
	var java_check_raw: String = await PyRunner.output_received
	PyRunner.stop()
	print("Received raw response data")
	java_check_raw = java_check_raw.strip_edges()
	if java_check_raw.begins_with("ERROR"):
		_on_error_received(java_check_raw.trim_prefix("ERROR").strip_edges())
		return false
	var jcl = java_check_raw.split(" ")
	if len(jcl) != 2:
		_on_error_received("Wrong length of java_check_list: %s" % java_check_raw)
		return false
	var java_version: String = jcl[0]
	java_check_result = str2bool(jcl[1])
	print("Java version check done! Current version: %s, check result: %s" % [
		java_version, "AFFECTED" if java_check_result else "Safe"])
	java_info_transfer.emit(java_version, java_check_result)
	return true

func run_cpu_set_check() -> bool:
	print("Starting cpu check Python script...")
	if not _start_python_entry_point(cpu_check_path): return false
	var cpu_check_raw: String = await PyRunner.output_received
	PyRunner.stop()
	cpu_check_raw = cpu_check_raw.strip_edges()
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
	if not java_check_result:
		final_result_transfer.emit(0)
	elif not cpu_check_total_result:
		final_result_transfer.emit(1)
	else:
		final_result_transfer.emit(2)

func str2bool(instr: String) -> bool:
	return instr.to_lower() == "true"
	
func _on_error_received(data: String) -> void:
	printerr(data)
	$ErrorPopup.visible = true
	$ErrorPopup/ErrorMargin/ErrorContainer/ErrorText/MsgBackground/ErrorMessage.text = data
