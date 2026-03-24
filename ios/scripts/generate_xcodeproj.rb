#!/usr/bin/env ruby
# frozen_string_literal: true

require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
PROJECT_NAME = 'VoiceVibeApp'
KEYBOARD_TARGET_NAME = 'VoiceVibeKeyboard'
PROJECT_PATH = File.join(ROOT, "#{PROJECT_NAME}.xcodeproj")

abort("#{PROJECT_NAME}.xcodeproj already exists. Remove it before regenerating.") if File.exist?(PROJECT_PATH)

project = Xcodeproj::Project.new(PROJECT_PATH)
project.build_configuration_list.build_configurations.each do |config|
  config.build_settings['SWIFT_VERSION'] = '5.0'
end

app_target = project.new_target(:application, PROJECT_NAME, :ios, '17.0')
app_target.product_reference.name = "#{PROJECT_NAME}.app"
keyboard_target = project.new_target(:app_extension, KEYBOARD_TARGET_NAME, :ios, '17.0')
keyboard_target.product_reference.name = "#{KEYBOARD_TARGET_NAME}.appex"

app_target.build_configurations.each do |config|
  settings = config.build_settings
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.psyhitech.voicevibe'
  settings['DEVELOPMENT_TEAM'] = 'DQ362F38WB'
  settings['PRODUCT_NAME'] = PROJECT_NAME
  settings['MARKETING_VERSION'] = '0.1.0'
  settings['CURRENT_PROJECT_VERSION'] = '1'
  settings['SWIFT_VERSION'] = '5.0'
  settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  settings['CODE_SIGN_STYLE'] = 'Automatic'
  settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  settings['INFOPLIST_KEY_CFBundleDisplayName'] = 'VoiceVibe'
  settings['INFOPLIST_KEY_LSRequiresIPhoneOS'] = 'YES'
  settings['INFOPLIST_KEY_NSMicrophoneUsageDescription'] = 'VoiceVibe needs microphone access for real-time transcription.'
  settings['INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents'] = 'YES'
  settings['INFOPLIST_KEY_UILaunchScreen_Generation'] = 'YES'
  settings['INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone'] = [
    'UIInterfaceOrientationPortrait'
  ]
  settings['INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad'] = [
    'UIInterfaceOrientationPortrait',
    'UIInterfaceOrientationPortraitUpsideDown',
    'UIInterfaceOrientationLandscapeLeft',
    'UIInterfaceOrientationLandscapeRight'
  ]
  settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  settings['CODE_SIGN_ENTITLEMENTS'] = 'VoiceVibeApp/App/VoiceVibeApp.entitlements'
  settings['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
end

keyboard_target.build_configurations.each do |config|
  settings = config.build_settings
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.psyhitech.voicevibe.keyboard'
  settings['DEVELOPMENT_TEAM'] = 'DQ362F38WB'
  settings['PRODUCT_NAME'] = KEYBOARD_TARGET_NAME
  settings['MARKETING_VERSION'] = '0.1.0'
  settings['CURRENT_PROJECT_VERSION'] = '1'
  settings['SWIFT_VERSION'] = '5.0'
  settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  settings['CODE_SIGN_STYLE'] = 'Automatic'
  settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  settings['INFOPLIST_FILE'] = 'VoiceVibeApp/KeyboardExtension/Info.plist'
  settings['CODE_SIGN_ENTITLEMENTS'] = 'VoiceVibeApp/KeyboardExtension/VoiceVibeKeyboard.entitlements'
  settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  settings['SKIP_INSTALL'] = 'YES'
  settings['LD_RUNPATH_SEARCH_PATHS'] = [
    '$(inherited)',
    '@executable_path/Frameworks',
    '@executable_path/../../Frameworks'
  ]
  settings['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
end

main_group = project.main_group.find_subpath(PROJECT_NAME, true)
main_group.set_source_tree('<group>')
main_group.set_path(PROJECT_NAME)

app_source_files = %w[
  App/VoiceVibeApp.swift
  Features/Home/HomeView.swift
  Features/Home/RecorderViewModel.swift
  Features/Home/SettingsView.swift
  Services/Audio/PCM16MonoAudioCaptureService.swift
  Services/ASR/DashScopeRealtimeASRClient.swift
  Support/DashScopeConfiguration.swift
  Support/SettingsStore.swift
]

shared_source_files = %w[
  Shared/AppGroup.swift
  Shared/SharedRecorderSnapshot.swift
  Shared/SharedRecorderStore.swift
]

keyboard_source_files = %w[
  KeyboardExtension/KeyboardRootView.swift
  KeyboardExtension/KeyboardViewController.swift
  KeyboardExtension/KeyboardViewModel.swift
]

other_visible_files = %w[
  App/VoiceVibeApp.entitlements
  KeyboardExtension/Info.plist
  KeyboardExtension/VoiceVibeKeyboard.entitlements
]

file_refs = {}

(app_source_files + shared_source_files + keyboard_source_files + other_visible_files).each do |path|
  file_refs[path] = main_group.new_file(path)
end

assets_ref = main_group.new_file('Resources/Assets.xcassets')
app_target.resources_build_phase.add_file_reference(assets_ref)

app_target.add_file_references(app_source_files.map { |path| file_refs.fetch(path) })
app_target.add_file_references(shared_source_files.map { |path| file_refs.fetch(path) })

keyboard_target.add_file_references(keyboard_source_files.map { |path| file_refs.fetch(path) })
keyboard_target.add_file_references(shared_source_files.map { |path| file_refs.fetch(path) })

app_target.add_dependency(keyboard_target)
embed_phase = app_target.new_copy_files_build_phase('Embed App Extensions')
embed_phase.dst_subfolder_spec = '13'
build_file = embed_phase.add_file_reference(keyboard_target.product_reference)
build_file.settings = { 'ATTRIBUTES' => %w[RemoveHeadersOnCopy] }

scheme = Xcodeproj::XCScheme.new
scheme.configure_with_targets(app_target, nil, launch_target: app_target)
scheme.save_as(PROJECT_PATH, PROJECT_NAME, true)

project.save
puts "Generated #{PROJECT_PATH}"
