#!/usr/bin/env ruby
# add_watchos_target.rb
# Adds a MyChannelWatch watchOS app target to MyChannel.xcodeproj.

require 'xcodeproj'

PROJECT_PATH  = File.expand_path('../MyChannel.xcodeproj', __dir__)
WATCH_DIR     = File.expand_path('../MyChannelWatch', __dir__)
TARGET_NAME   = 'MyChannelWatch'
BUNDLE_ID     = 'com.keontapeat.MyChannelApp.watchkitapp'
TEAM_ID       = '8KPXZ859S7'
SWIFT_VERSION = '5.0'
WATCHOS_DEPLOY = '8.0'    # watchOS 8 = SwiftUI + WatchConnectivity + ClockKit complications
COMPANION_BUNDLE = 'com.keontapeat.MyChannelApp'

project = Xcodeproj::Project.open(PROJECT_PATH)

if project.targets.any? { |t| t.name == TARGET_NAME }
  puts "✅  #{TARGET_NAME} target already exists — nothing to do."
  exit 0
end

# ── 1. Create watchOS app target ───────────────────────────────────────────
watch_target = project.new_target(
  :watch2_app,        # watchkitapp product type (watchOS 7+ SwiftUI app)
  TARGET_NAME,
  :watchos,
  WATCHOS_DEPLOY
)
puts "⌚️  Created target: #{TARGET_NAME}"

# ── 2. Build configurations ────────────────────────────────────────────────
['Debug', 'Release'].each do |config|
  s = watch_target.build_settings(config)

  s['PRODUCT_BUNDLE_IDENTIFIER']    = BUNDLE_ID
  s['DEVELOPMENT_TEAM']             = TEAM_ID
  s['SWIFT_VERSION']                = SWIFT_VERSION
  s['WATCHOS_DEPLOYMENT_TARGET']    = WATCHOS_DEPLOY
  s['INFOPLIST_FILE']               = 'MyChannelWatch/Info.plist'
  s['PRODUCT_NAME']                 = TARGET_NAME
  s['TARGETED_DEVICE_FAMILY']       = '4'         # 4 = Apple Watch
  s['CODE_SIGN_STYLE']              = 'Automatic'
  s['ENABLE_PREVIEWS']              = 'YES'
  s['SWIFT_OPTIMIZATION_LEVEL']     = config == 'Debug' ? '-Onone' : '-O'
  s['DEBUG_INFORMATION_FORMAT']     = config == 'Debug' ? 'dwarf' : 'dwarf-with-dsym'
  s['SWIFT_COMPILATION_MODE']       = config == 'Debug' ? 'incremental' : 'wholemodule'
  s['ENABLE_TESTABILITY']           = config == 'Debug' ? 'YES' : 'NO'
  s['ONLY_ACTIVE_ARCH']             = config == 'Debug' ? 'YES' : 'NO'
  s['OTHER_SWIFT_FLAGS']            = '$(inherited)'
  s['WK_APPLICATION_EXTENSION_ALLOWED_APIS_ONLY'] = 'NO'
  s['SDKROOT']                      = 'watchos'
  s['SUPPORTED_PLATFORMS']          = 'watchos watchsimulator'

  if config == 'Debug'
    s['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG'
    s['COMPILER_INDEX_STORE_ENABLE']         = 'NO'
  end
end
puts "⚙️   Build settings configured"

# ── 3. Add source files ─────────────────────────────────────────────────────
watch_group = project['MyChannelWatch'] ||
              project.main_group.new_group('MyChannelWatch', 'MyChannelWatch')

swift_files = Dir[File.join(WATCH_DIR, '*.swift')]
sources_phase = watch_target.source_build_phase
swift_files.each do |path|
  ref = watch_group.files.find { |f| f.real_path.to_s == path }
  ref ||= watch_group.new_file(path)
  sources_phase.add_file_reference(ref) unless sources_phase.files_references.include?(ref)
  puts "  + #{File.basename(path)}"
end
puts "📄  Added #{swift_files.size} Swift source(s)"

# ── 4. Add Info.plist reference ─────────────────────────────────────────────
plist_path = File.join(WATCH_DIR, 'Info.plist')
plist_ref = watch_group.files.find { |f| f.real_path.to_s == plist_path }
plist_ref ||= watch_group.new_file(plist_path)

# ── 5. Link companion (iOS) app ─────────────────────────────────────────────
# Set WKCompanionAppBundleIdentifier so Xcode pairs the watch app with the iOS app
ios_target = project.targets.find { |t| t.name == 'MyChannel' }
if ios_target
  # Add the watch app as an embedded watch application in the iOS target
  # This creates the dependency and embed build phase automatically
  embed_phase = ios_target.build_phases.find { |p|
    p.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase) &&
    p.dst_subfolder_spec == '16'  # 16 = WatchApp
  }
  unless embed_phase
    embed_phase = ios_target.new_copy_files_build_phase('Embed Watch Content')
    embed_phase.dst_path = '$(CONTENTS_FOLDER_PATH)/Watch'
    embed_phase.dst_subfolder_spec = '16'
  end

  watch_product = watch_target.product_reference
  if watch_product && embed_phase.files_references.none? { |r| r == watch_product }
    embed_file = embed_phase.add_file_reference(watch_product)
    embed_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
    puts "📎  Linked watch app into iOS target embed phase"
  end

  ios_target.add_dependency(watch_target)
  puts "🔗  Added watch target as dependency of MyChannel (iOS)"
end

# ── 6. Save ─────────────────────────────────────────────────────────────────
project.save
puts "\n✅  #{TARGET_NAME} watchOS target added to MyChannel.xcodeproj"
puts "   Bundle ID  : #{BUNDLE_ID}"
puts "   Deployment : watchOS #{WATCHOS_DEPLOY}"
puts "   Companion  : #{COMPANION_BUNDLE}"
puts "   Team       : #{TEAM_ID}"
puts "\n👉  Next:"
puts "   1. Open Xcode — the MyChannelWatch scheme should appear automatically."
puts "   2. Select the MyChannelWatch scheme and build for a watch simulator."
puts "   3. Add Firebase SDK to the watch target if you want direct Firestore reads."
