@tool
extends Control

# UI Components
var record_btn: Button
var stop_btn: Button
var play_btn: Button
var save_btn: Button

var file_name_input: LineEdit
var format_option: OptionButton
var sample_rate_option: OptionButton
var mic_device_option: OptionButton
var preset_option: OptionButton

var pitch_slider: HSlider
var pitch_label: Label
var volume_slider: HSlider
var volume_label: Label

var trim_start_slider: HSlider
var trim_end_slider: HSlider
var trim_start_label: Label
var trim_end_label: Label

var status_label: Label
var volume_bar: ProgressBar
var normalize_check: CheckBox

# Audio Systems
var effect_capture: AudioEffectRecord
var effect_spectrum: AudioEffectSpectrumAnalyzerInstance
var recording: AudioStreamWAV
var audio_player: AudioStreamPlayer
var mic_player: AudioStreamPlayer
var is_recording: bool = false

func _enter_tree() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	custom_minimum_size = Vector2(600, 500)
	_setup_ui()
	_ensure_audio_bus_setup()

func _process(_delta: float) -> void:
	if is_recording and effect_spectrum:
		var mag = effect_spectrum.get_magnitude_for_frequency_range(20, 20000).length()
		if volume_bar:
			volume_bar.value = clamp(mag * 3500.0, 0.0, 100.0)

func _setup_ui() -> void:
	for c in get_children():
		c.queue_free()

	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(scroll)

	var main_vbox = VBoxContainer.new()
	main_vbox.custom_minimum_size = Vector2(680, 520)
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(main_vbox)

	# --- Header ---
	var title = Label.new()
	title.text = "🎙️ GODOT AUDIO STUDIO PRO (ADVANCED VOICE & RECORDING WORKSTATION)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)

	status_label = Label.new()
	status_label.text = "Status: Connected to System Audio Driver & Mic Input"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(status_label)

	main_vbox.add_child(HSeparator.new())

	# --- Mic & Audio Settings ---
	var mic_hbox = HBoxContainer.new()
	main_vbox.add_child(mic_hbox)

	var mic_lbl = Label.new()
	mic_lbl.text = "Select Microphone: "
	mic_hbox.add_child(mic_lbl)

	mic_device_option = OptionButton.new()
	mic_device_option.custom_minimum_size = Vector2(280, 30)
	_populate_mic_devices()
	mic_device_option.item_selected.connect(_on_mic_device_selected)
	mic_hbox.add_child(mic_device_option)

	var sr_lbl = Label.new()
	sr_lbl.text = " Sample Rate: "
	mic_hbox.add_child(sr_lbl)

	sample_rate_option = OptionButton.new()
	sample_rate_option.add_item("44100 Hz")
	sample_rate_option.add_item("48000 Hz")
	sample_rate_option.add_item("22050 Hz")
	mic_hbox.add_child(sample_rate_option)

	main_vbox.add_child(HSeparator.new())

	# --- Visualizer Meter ---
	var wave_label = Label.new()
	wave_label.text = "📊 Live Audio Input Volume Level:"
	main_vbox.add_child(wave_label)

	volume_bar = ProgressBar.new()
	volume_bar.custom_minimum_size = Vector2(0, 25)
	main_vbox.add_child(volume_bar)

	main_vbox.add_child(HSeparator.new())

	# --- Control Buttons ---
	var grid = HBoxContainer.new()
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(grid)

	record_btn = Button.new()
	record_btn.text = "🔴 START RECORDING"
	record_btn.custom_minimum_size = Vector2(170, 42)
	record_btn.pressed.connect(_on_record_pressed)
	grid.add_child(record_btn)

	stop_btn = Button.new()
	stop_btn.text = "⏹️ STOP"
	stop_btn.disabled = true
	stop_btn.custom_minimum_size = Vector2(110, 42)
	stop_btn.pressed.connect(_on_stop_pressed)
	grid.add_child(stop_btn)

	play_btn = Button.new()
	play_btn.text = "▶️ PLAYBACK"
	play_btn.disabled = true
	play_btn.custom_minimum_size = Vector2(170, 42)
	play_btn.pressed.connect(_on_play_pressed)
	grid.add_child(play_btn)

	main_vbox.add_child(HSeparator.new())

	# --- Presets & FX ---
	var preset_hbox = HBoxContainer.new()
	main_vbox.add_child(preset_hbox)

	var pr_label = Label.new()
	pr_label.text = "Voice Presets: "
	preset_hbox.add_child(pr_label)

	preset_option = OptionButton.new()
	preset_option.add_item("Default / Normal")
	preset_option.add_item("Deep Monster (0.65)")
	preset_option.add_item("High Chipmunk (1.6)")
	preset_option.add_item("Robot Effect (1.2)")
	preset_option.item_selected.connect(_on_preset_selected)
	preset_hbox.add_child(preset_option)

	normalize_check = CheckBox.new()
	normalize_check.text = "Normalize Volume Gain"
	preset_hbox.add_child(normalize_check)

	# --- Sliders (Pitch & Volume Boost) ---
	var pitch_hbox = HBoxContainer.new()
	main_vbox.add_child(pitch_hbox)

	var p_label = Label.new()
	p_label.text = "Voice Pitch Modulation (0.3 - 2.5): "
	pitch_hbox.add_child(p_label)

	pitch_slider = HSlider.new()
	pitch_slider.min_value = 0.3
	pitch_slider.max_value = 2.5
	pitch_slider.step = 0.05
	pitch_slider.value = 1.0
	pitch_slider.custom_minimum_size = Vector2(160, 20)
	pitch_slider.value_changed.connect(func(val): pitch_label.text = str(val))
	pitch_hbox.add_child(pitch_slider)

	pitch_label = Label.new()
	pitch_label.text = "1.0"
	pitch_hbox.add_child(pitch_label)

	var vol_hbox = HBoxContainer.new()
	main_vbox.add_child(vol_hbox)

	var v_label = Label.new()
	v_label.text = "Volume Boost Multiplier (0x - 3x): "
	vol_hbox.add_child(v_label)

	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 3.0
	volume_slider.step = 0.1
	volume_slider.value = 1.0
	volume_slider.custom_minimum_size = Vector2(160, 20)
	volume_slider.value_changed.connect(func(val): volume_label.text = str(val) + "x")
	vol_hbox.add_child(volume_slider)

	volume_label = Label.new()
	volume_label.text = "1.0x"
	vol_hbox.add_child(volume_label)

	main_vbox.add_child(HSeparator.new())

	# --- Export Settings ---
	var save_grid = HBoxContainer.new()
	save_grid.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(save_grid)

	var f_title = Label.new()
	f_title.text = "Export Path: res://"
	save_grid.add_child(f_title)

	file_name_input = LineEdit.new()
	file_name_input.text = "studio_voice_track"
	file_name_input.custom_minimum_size = Vector2(170, 32)
	save_grid.add_child(file_name_input)

	format_option = OptionButton.new()
	format_option.add_item(".wav")
	format_option.add_item(".mp3")
	format_option.add_item(".ogg")
	save_grid.add_child(format_option)

	save_btn = Button.new()
	save_btn.text = "💾 SAVE AUDIO"
	save_btn.disabled = true
	save_btn.custom_minimum_size = Vector2(130, 32)
	save_btn.pressed.connect(_on_save_pressed)
	save_grid.add_child(save_btn)

func _populate_mic_devices() -> void:
	mic_device_option.clear()
	var devices = AudioServer.get_input_device_list()
	for dev in devices:
		mic_device_option.add_item(dev)
	
	var current_device = AudioServer.get_input_device()
	for i in range(devices.size()):
		if devices[i] == current_device:
			mic_device_option.select(i)
			break

func _on_mic_device_selected(index: int) -> void:
	var selected_device = mic_device_option.get_item_text(index)
	AudioServer.set_input_device(selected_device)
	status_label.text = "Status: Active Mic -> " + selected_device

func _on_preset_selected(index: int) -> void:
	match index:
		0: pitch_slider.value = 1.0
		1: pitch_slider.value = 0.65
		2: pitch_slider.value = 1.60
		3: pitch_slider.value = 1.20

func _ensure_audio_bus_setup() -> void:
	ProjectSettings.set_setting("audio/driver/enable_input", true)

	if not audio_player:
		audio_player = AudioStreamPlayer.new()
		add_child(audio_player)

	if not mic_player:
		mic_player = AudioStreamPlayer.new()
		var mic_stream = AudioStreamMicrophone.new()
		mic_player.stream = mic_stream
		mic_player.bus = "Record"
		add_child(mic_player)

	var bus_idx = AudioServer.get_bus_index("Record")
	if bus_idx == -1:
		AudioServer.add_bus()
		bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_idx, "Record")

	AudioServer.set_bus_mute(bus_idx, false)
	AudioServer.set_bus_volume_db(bus_idx, 0.0)
	AudioServer.set_bus_send(bus_idx, "Master")

	for i in range(AudioServer.get_bus_effect_count(bus_idx) - 1, -1, -1):
		AudioServer.remove_bus_effect(bus_idx, i)

	effect_capture = AudioEffectRecord.new()
	AudioServer.add_bus_effect(bus_idx, effect_capture)

	var spec_eff = AudioEffectSpectrumAnalyzer.new()
	AudioServer.add_bus_effect(bus_idx, spec_eff)

	effect_spectrum = AudioServer.get_bus_effect_instance(bus_idx, 1)

func _on_record_pressed() -> void:
	_ensure_audio_bus_setup()
	
	if mic_player and not mic_player.playing:
		mic_player.play()

	if effect_capture:
		effect_capture.set_recording_active(false)
		effect_capture.set_recording_active(true)
		is_recording = true
		record_btn.disabled = true
		stop_btn.disabled = false
		play_btn.disabled = true
		save_btn.disabled = true
		status_label.text = "Status: 🎙️ RECORDING LIVE MIC INPUT..."

func _on_stop_pressed() -> void:
	if effect_capture:
		recording = effect_capture.get_recording()
		effect_capture.set_recording_active(false)
		is_recording = false
		
		if mic_player:
			mic_player.stop()

		volume_bar.value = 0
		record_btn.disabled = false
		stop_btn.disabled = true
		
		if recording and recording.data.size() > 0:
			play_btn.disabled = false
			save_btn.disabled = false
			status_label.text = "Status: ⏹️ Recording Complete! Preview or Save."
		else:
			status_label.text = "Status: ⚠️ No audio input detected from selected Mic."

func _on_play_pressed() -> void:
	if recording and audio_player:
		audio_player.stream = recording
		audio_player.pitch_scale = pitch_slider.value
		audio_player.volume_db = linear_to_db(volume_slider.value)
		audio_player.play()
		status_label.text = "Status: ▶️ Playing back audio stream..."

func _on_save_pressed() -> void:
	if recording:
		var ext = format_option.get_item_text(format_option.selected)
		var file_path = "res://" + file_name_input.text + ext
		var err = recording.save_to_wav(file_path)
		
		if err == OK:
			status_label.text = "Status: 💾 Audio File Saved Successfully to " + file_path
			if Engine.is_editor_hint():
				EditorInterface.get_resource_filesystem().scan()
		else:
			status_label.text = "Status: ❌ Save Failed!"
