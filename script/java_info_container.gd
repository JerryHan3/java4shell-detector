extends VBoxContainer

@export var safe_icon: DPITexture
@export_color_no_alpha var safe_color: Color = Color("#059e38")
@export var affected_icon: DPITexture
@export_color_no_alpha var affected_color: Color = Color("#d0021b")
@export var checking_icon: DPITexture
@export_color_no_alpha var checking_color: Color = Color("#4a90e2")

func _on_main_java_info_transfer(verstr: String, result: bool) -> void:
	$Version/VersionLabel.text = verstr
	if result:
		$Result/Icon.texture = affected_icon
		$Result/ResultDisplay.text = tr("java_check.result.affected")
		$Result/ResultDisplay.label_settings.font_color = affected_color
	else:
		$Result/Icon.texture = safe_icon
		$Result/ResultDisplay.text = tr("java_check.result.safe")
		$Result/ResultDisplay.label_settings.font_color = safe_color

func _on_checking_java_version():
	$Result/Icon.texture = checking_icon
	$Result/ResultDisplay.text = tr("java_check.result.checking")
	$Result/ResultDisplay.label_settings.font_color = checking_color
