extends EditorExportPlugin

const interpreter_dir:String = 'res://addons/PyBundle/Interpreter/'
## Architecture feature names as reported by [method @GlobalScope.Engine.get_architecture_name].
const known_architectures:PackedStringArray = [
	'x86_64', 'x86_32', 'arm64', 'arm32', 'riscv64', 'ppc64', 'wasm32',
]


func _get_name() -> String:
	return 'PyBundle'


## Returns the platform component of a binary name, e.g. [code].windows[/code].
## [br]Derived from the [b]export target[/b] (the preset being exported) rather than the
## host OS, so exporting the Windows preset from a Linux editor still picks the Windows
## interpreter.
static func _target_platform(features:PackedStringArray) -> String:
	if features.has('windows'):
		return '.windows'
	if features.has('macos'):
		return '.mac'
	if features.has('linux') or features.has('bsd') or features.has('linuxbsd'):
		return '.linux'
	return '.other'


## Returns the architecture component of a binary name, e.g. [code]x86_64[/code], or an
## empty string when [param features] carries no architecture marker (match by platform only).
static func _target_architecture(features:PackedStringArray) -> String:
	for architecture:String in known_architectures:
		if features.has(architecture): return architecture
	return ''


func _export_begin(features:PackedStringArray, _is_debug:bool, _path:String, _flags:int) -> void:

	# Add binaries (for the export target's platform & architecture).
	var platform:String = _target_platform(features)
	var architecture:String = _target_architecture(features)
	# Windows binaries end in ".exe", every other platform in ".bin".
	var exe_extension:String = 'exe' if platform == '.windows' else 'bin'
	# Full expected file stem, e.g. "windows.x86_64", or just "windows" without an arch marker.
	# [BinBundleProcess] builds the runtime filename as exe_dir + platform extension + ".exe",
	# where the platform extension already carries a leading dot, so the file itself has none.
	var wanted_stem:String = platform.lstrip('.') + ('.'+architecture if not architecture.is_empty() else '')

	var added_binaries:int = 0
	var available_binaries:Array[String] = []
	for path:String in DirAccess.get_files_at(interpreter_dir):
		if path.get_extension() != exe_extension: continue
		available_binaries.append(path)
		if path.get_basename() != wanted_stem: continue
		add_file(interpreter_dir+path, FileAccess.get_file_as_bytes(interpreter_dir+path), false)
		added_binaries += 1

	if added_binaries == 0:
		var expected_name:String = wanted_stem + '.' + exe_extension
		var available:String = ', '.join(available_binaries) if not available_binaries.is_empty() else '(none found)'
		push_error('PyBundle: no interpreter binary for the export target found in %s. Expected "%s" (export features: [%s]). Available %s files: %s. Build the missing interpreter on a machine of that platform and copy it into the project, otherwise the exported program cannot start Python.' % [
			interpreter_dir, expected_name, ', '.join(features), exe_extension, available])

	# Add Python scripts.
	BinBundleUtil.walk_dir('res://', func(script_path:String) -> void:
		if script_path.get_extension() != 'py': return
		add_file(script_path, FileAccess.get_file_as_bytes(script_path), false)
	)
