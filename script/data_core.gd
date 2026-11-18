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
	
	await run_java_version_check()
	await run_cpu_set_check()
	update_final_result()

func run_java_version_check():
	var java_path = $VSplitContainer/DetectionContainer/StartupScreen/JavaFileSelect/FileSelection.text
	if java_path == "": java_path = "java"
	print("Starting java check Python script...")
	PyRunner.start_entry_point(java_check_path)
	await PyRunner.started
	print("Script started, sending path...")
	PyRunner.send_input(java_path)
	print("Path sended, waiting response...")
	var java_check_raw: String = await PyRunner.output_received
	print("Received raw response data")
	var java_version: String = java_check_raw.split(" ")[0]
	java_check_result = str2bool(java_check_raw.split(" ")[1])
	print("Java version check done! Current version: " + java_version + ", check result: " + "AFFECTED" if java_check_result else "Safe")
	java_info_transfer.emit(java_version, java_check_result)
	await PyRunner.stopped
	return

func run_cpu_set_check():
	PyRunner.start_entry_point(cpu_check_path)
	var cpu_check_raw: String = await PyRunner.output_received
	var ccl = cpu_check_raw.split(" ")
	if len(ccl) != 4: 
		printerr("Wrong length of cpu_check_list")
		return
	cpu_check_total_result = ccl[0] and ccl[1] and ccl[2] and ccl[3]
	cpu_info_transfer.emit(ccl[0], ccl[1], ccl[2], ccl[3])
	await PyRunner.stopped
	return

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
