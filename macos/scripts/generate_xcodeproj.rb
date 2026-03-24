#!/usr/bin/env ruby
# frozen_string_literal: true

require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
PROJECT_NAME = 'VoiceVibeMac'
APP_PRODUCT_NAME = 'VoiceVibe'
PROJECT_PATH = File.join(ROOT, "#{PROJECT_NAME}.xcodeproj")

abort("#{PROJECT_NAME}.xcodeproj already exists. Remove it before regenerating.") if File.exist?(PROJECT_PATH)

project = Xcodeproj::Project.new(PROJECT_PATH)
project.build_configuration_list.build_configurations.each do |config|
  config.build_settings['SWIFT_VERSION'] = '5.0'
end

target = project.new_target(:application, PROJECT_NAME, :osx, '14.0')
target.product_reference.name = "#{APP_PRODUCT_NAME}.app"
target.product_reference.path = "#{APP_PRODUCT_NAME}.app"

target.build_configurations.each do |config|
  settings = config.build_settings
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.psyhitech.voicevibe.mac'
  settings['DEVELOPMENT_TEAM'] = 'DQ362F38WB'
  settings['PRODUCT_NAME'] = APP_PRODUCT_NAME
  settings['MARKETING_VERSION'] = '0.1.0'
  settings['CURRENT_PROJECT_VERSION'] = '1'
  settings['SWIFT_VERSION'] = '5.0'
  settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
  settings['CODE_SIGN_STYLE'] = 'Automatic'
  settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  settings['INFOPLIST_KEY_CFBundleDisplayName'] = 'VoiceVibe'
  settings['INFOPLIST_KEY_NSMicrophoneUsageDescription'] = 'VoiceVibe needs microphone access for real-time transcription.'
  settings['INFOPLIST_KEY_NSHighResolutionCapable'] = 'YES'
  settings['LD_RUNPATH_SEARCH_PATHS'] = [
    '$(inherited)',
    '@executable_path/../Frameworks'
  ]
  settings['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
end

main_group = project.main_group.find_subpath(PROJECT_NAME, true)
main_group.set_source_tree('<group>')
main_group.set_path(PROJECT_NAME)

source_files = %w[
  App/main.swift
  App/AppDelegate.swift
  App/MacAppModel.swift
  App/StatusBarController.swift
  Features/Main/MainView.swift
  Features/Main/MenuBarView.swift
  Features/Overlay/CapsuleOverlayView.swift
  Models/OverlayState.swift
  Models/PermissionState.swift
  Models/RecordingState.swift
  Services/ASR/DashScopeRealtimeASRClient.swift
  Services/Audio/MacAudioCaptureService.swift
  Services/Input/FnKeyMonitor.swift
  Services/Input/FocusedTextInjector.swift
  Services/Overlay/CapsuleOverlayWindowController.swift
  Support/DashScopeConfiguration.swift
  Support/SettingsStore.swift
]

resource_files = %w[
  Resources/Assets.xcassets
]

file_refs = {}
source_files.each do |path|
  file_refs[path] = main_group.new_file(path)
end

target.add_file_references(source_files.map { |path| file_refs.fetch(path) })

resource_files.each do |path|
  file_refs[path] = main_group.new_file(path)
end

target.resources_build_phase.add_file_reference(file_refs.fetch('Resources/Assets.xcassets'))

scheme = Xcodeproj::XCScheme.new
scheme.configure_with_targets(target, nil, launch_target: target)
scheme.save_as(PROJECT_PATH, PROJECT_NAME, true)

project.save
puts "Generated #{PROJECT_PATH}"
