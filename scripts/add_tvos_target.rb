#!/usr/bin/env ruby
# add_tvos_target.rb
# Adds a MyChannelTV tvOS target to MyChannel.xcodeproj using the xcodeproj gem.
# Run: ruby scripts/add_tvos_target.rb

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../MyChannel.xcodeproj', __dir__)
TVCONTENT_DIR = File.expand_path('../MyChannelTV', __dir__)
TARGET_NAME   = 'MyChannelTV'
BUNDLE_ID     = 'com.keontapeat.MyChannelTV'
TEAM_ID       = '8KPXZ859S7'
SWIFT_VERSION = '5.0'
TVOS_DEPLOY   = '15.0'

project = Xcodeproj::Project.open(PROJECT_PATH)

# Guard — don't add twice
if project.targets.any? { |t| t.name == TARGET_NAME }
  puts "✅  #{TARGET_NAME} target already exists — nothing to do."
  exit 0
end

# ── 1. Create native target ────────────────────────────────────────────────
tv_target = project.new_target(
  :application,      # product type
  TARGET_NAME,
  :tvos,
  TVOS_DEPLOY
)
puts "📺  Created target: #{TARGET_NAME}"

# ── 2. Build configurations ───────────────────────────────────────────────
['Debug', 'Release'].each do |config|
  settings = tv_target.build_settings(config)

  settings['PRODUCT_BUNDLE_IDENTIFIER']    = BUNDLE_ID
  settings['DEVELOPMENT_TEAM']             = TEAM_ID
  settings['SWIFT_VERSION']                = SWIFT_VERSION
  settings['TVOS_DEPLOYMENT_TARGET']       = TVOS_DEPLOY
  settings['INFOPLIST_FILE']               = 'MyChannelTV/Info.plist'
  settings['PRODUCT_NAME']                 = TARGET_NAME
  settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'App Icon & Top Shelf Image'
  settings['TARGETED_DEVICE_FAMILY']       = '3'           # 3 = Apple TV
  settings['SWIFT_OPTIMIZATION_LEVEL']     = config == 'Debug' ? '-Onone' : '-O'
  settings['DEBUG_INFORMATION_FORMAT']     = config == 'Debug' ? 'dwarf' : 'dwarf-with-dsym'
  settings['SWIFT_COMPILATION_MODE']       = config == 'Debug' ? 'incremental' : 'wholemodule'
  settings['ENABLE_TESTABILITY']           = config == 'Debug' ? 'YES' : 'NO'
  settings['ONLY_ACTIVE_ARCH']             = config == 'Debug' ? 'YES' : 'NO'
  settings['CODE_SIGN_STYLE']              = 'Automatic'
  settings['ENABLE_PREVIEWS']              = 'YES'

  # Swift flags matching the iOS target
  settings['OTHER_SWIFT_FLAGS'] = '$(inherited)'
  settings['GCC_PREPROCESSOR_DEFINITIONS'] = ['$(inherited)', config == 'Debug' ? 'DEBUG=1' : '']
                                               .reject(&:empty?)

  if config == 'Debug'
    settings['WARNING_CFLAGS']                        = '-warn-long-function-bodies=100 -warn-long-expression-type-checking=100'
    settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS']   = 'DEBUG'
    settings['COMPILER_INDEX_STORE_ENABLE']           = 'NO'
  else
    settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS']   = ''
  end
end
puts "⚙️   Build settings configured for Debug + Release"

# ── 3. Add source files ────────────────────────────────────────────────────
# Create a group for the tvOS files if it doesn't already exist
tv_group = project['MyChannelTV'] ||
           project.main_group.new_group('MyChannelTV', 'MyChannelTV')

swift_files = Dir[File.join(TVCONTENT_DIR, '*.swift')]
if swift_files.empty?
  puts "⚠️   No .swift files found in #{TVCONTENT_DIR}"
else
  sources_phase = tv_target.source_build_phase
  swift_files.each do |path|
    file_ref = tv_group.files.find { |f| f.real_path.to_s == path }
    file_ref ||= tv_group.new_file(path)
    sources_phase.add_file_reference(file_ref) unless
      sources_phase.files_references.include?(file_ref)
    puts "  + #{File.basename(path)}"
  end
  puts "📄  Added #{swift_files.size} source file(s)"
end

# ── 4. Create a minimal Info.plist ────────────────────────────────────────
plist_path = File.join(TVCONTENT_DIR, 'Info.plist')
unless File.exist?(plist_path)
  plist_content = <<~PLIST
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
      "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleDevelopmentRegion</key>
      <string>$(DEVELOPMENT_LANGUAGE)</string>
      <key>CFBundleExecutable</key>
      <string>$(EXECUTABLE_NAME)</string>
      <key>CFBundleIdentifier</key>
      <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
      <key>CFBundleInfoDictionaryVersion</key>
      <string>6.0</string>
      <key>CFBundleName</key>
      <string>$(PRODUCT_NAME)</string>
      <key>CFBundlePackageType</key>
      <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
      <key>CFBundleShortVersionString</key>
      <string>1.0</string>
      <key>CFBundleVersion</key>
      <string>1</string>
      <key>UIMainStoryboardFile</key>
      <string></string>
      <key>NSPrincipalClass</key>
      <string></string>
    </dict>
    </plist>
  PLIST
  File.write(plist_path, plist_content)
  puts "📋  Created MyChannelTV/Info.plist"
end

# ── 5. Add the plist to the project file references ───────────────────────
plist_ref = tv_group.files.find { |f| f.real_path.to_s == plist_path }
plist_ref ||= tv_group.new_file(plist_path)

# ── 6. Add a Resources phase with the plist (needed so Xcode can find it) ─
# (Sources phase already added above; Resources phase auto-created by new_target)

# ── 7. Save ────────────────────────────────────────────────────────────────
project.save
puts "\n✅  #{TARGET_NAME} tvOS target added to MyChannel.xcodeproj"
puts "   Bundle ID : #{BUNDLE_ID}"
puts "   Deployment: tvOS #{TVOS_DEPLOY}"
puts "   Team      : #{TEAM_ID}"
puts "\n👉  Next: open Xcode, select the MyChannelTV scheme, and build."
