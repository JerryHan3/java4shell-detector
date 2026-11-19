extends Control

@export var safe_icon: DPITexture
@export_color_no_alpha var safe_color: Color = Color("#059e38")
@export var risk_icon: DPITexture
@export_color_no_alpha var risk_color: Color = Color("#f5a623")
@export var danger_icon: DPITexture
@export_color_no_alpha var danger_color: Color = Color("#d0021b")
@export var checking_icon: DPITexture
@export_color_no_alpha var checking_color: Color = Color("#4a90e2")

func _on_main_final_result_transfer(result: int) -> void:
	if result == 0:
		$IconMargin/MajorIcon.texture = safe_icon
		$VBoxContainer/Issue.text = tr("final_result.safe.issue")
		$VBoxContainer/Issue.label_settings.font_color = safe_color
		$VBoxContainer/Fix.text = tr("final_result.safe.fix")
		$VBoxContainer/Fix.label_settings.font_color = safe_color
	elif result == 1:
		$IconMargin/MajorIcon.texture = risk_icon
		$VBoxContainer/Issue.text = tr("final_result.risk.issue")
		$VBoxContainer/Issue.label_settings.font_color = risk_color
		$VBoxContainer/Fix.text = tr("final_result.risk.fix")
		$VBoxContainer/Fix.label_settings.font_color = risk_color
	elif result == 2:
		$IconMargin/MajorIcon.texture = danger_icon
		$VBoxContainer/Issue.text = tr("final_result.danger.issue")
		$VBoxContainer/Issue.label_settings.font_color = danger_color
		$VBoxContainer/Fix.text = tr("final_result.danger.fix")
		$VBoxContainer/Fix.label_settings.font_color = danger_color
	else:
		
		$IconMargin/MajorIcon.texture = risk_icon
		$VBoxContainer/Issue.text = tr("final_result.not_found.issue")
		$VBoxContainer/Issue.label_settings.font_color = risk_color
		$VBoxContainer/Fix.text = tr("final_result.not_found.fix")
		$VBoxContainer/Fix.label_settings.font_color = risk_color
