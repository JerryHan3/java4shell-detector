extends Control

@export var safe_icon: DPITexture
@export_color_no_alpha var safe_color: Color = Color("#059e38")
@export var affected_icon: DPITexture
@export_color_no_alpha var affected_color: Color = Color("#d0021b")
@export var checking_icon: DPITexture
@export_color_no_alpha var checking_color: Color = Color("#4a90e2")


func _on_main_cpu_info_transfer(avx512f: bool, avx512bw: bool, avx512vbmi: bool, bmi2: bool, arch: String) -> void:
	update_child($AVX512BW, avx512bw)
	update_child($AVX512F, avx512f)
	update_child($AVX512VBMI, avx512vbmi)
	update_child($BMI2, bmi2)
	
	$CPUArch/Result.text = arch
	if arch == "x86_64":
		$CPUArch/Icon.texture = affected_icon
		$CPUArch/Result.label_settings.font_color = affected_color
	else:
		$CPUArch/Icon.texture = safe_icon
		$CPUArch/Result.label_settings.font_color = safe_color
	
func update_child(target: Node, result: bool) -> void:
	if result:
		target.get_node_or_null("Icon").texture = affected_icon
		target.get_node_or_null("Result").text = tr("cpu_check.result.supported")
		target.get_node_or_null("Result").label_settings.font_color = affected_color
	else:
		target.get_node_or_null("Icon").texture = safe_icon
		target.get_node_or_null("Result").text = tr("cpu_check.result.unsupported")
		target.get_node_or_null("Result").label_settings.font_color = safe_color

func reset_child(target: Node) -> void:
	target.get_node_or_null("Icon").texture = checking_icon
	target.get_node_or_null("Result").text = tr("general.checking")
	target.get_node_or_null("Result").label_settings.font_color = checking_color

func _on_main_reset_all_screen() -> void:
	reset_child($AVX512BW)
	reset_child($AVX512F)
	reset_child($AVX512VBMI)
	reset_child($BMI2)
	reset_child($CPUArch)
