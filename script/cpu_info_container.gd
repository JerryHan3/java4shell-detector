extends Control

@export var safe_icon: DPITexture
@export_color_no_alpha var safe_color: Color = Color("#059e38")
@export var affected_icon: DPITexture
@export_color_no_alpha var affected_color: Color = Color("#d0021b")
@export var checking_icon: DPITexture
@export_color_no_alpha var checking_color: Color = Color("#4a90e2")


func _on_main_cpu_info_transfer(avx512f: bool, avx512bw: bool, avx512vbmi: bool, bmi2: bool) -> void:
	update_child($AVX512BW, avx512bw)
	update_child($AVX512F, avx512f)
	update_child($AVX512VBMI, avx512vbmi)
	update_child($BMI2, bmi2)
	
func update_child(target: Node, result: bool) -> void:
	if result:
		target.get_node_or_null("Icon").texture = affected_icon
		target.get_node_or_null("Result").text = tr("cpu_check.result.supported")
		target.get_node_or_null("Result").label_settings.font_color = affected_color
	else:
		target.get_node_or_null("Icon").texture = safe_icon
		target.get_node_or_null("Result").text = tr("cpu_check.result.unsupported")
		target.get_node_or_null("Result").label_settings.font_color = safe_color
