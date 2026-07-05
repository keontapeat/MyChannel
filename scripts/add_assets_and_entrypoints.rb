#!/usr/bin/env ruby
# add_assets_and_entrypoints.rb
# Adds Assets.xcassets and MyChannelTVApp.swift to the tvOS + watchOS targets.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../MyChannel.xcodeproj', __dir__)
project = Xcodeproj::Project.open(PROJECT_PATH)

tv_target    = project.targets.find { |t| t.name == 'MyChannelTV' }
watch_target = project.targets.find { |t| t.name == 'MyChannelWatch' }

abort "❌  MyChannelTV target not found" unless tv_target
abort "❌  MyChannelWatch target not found" unless watch_target

# ── Helper ──────────────────────────────────────────────────────────────────
def add_file(group, target, path, build_phase: :sources)
  ref = group.files.find { |f| f.real_path.to_s == path }
  ref ||= group.new_file(path)

  phase = case build_phase
  when :sources
    target.source_build_phase
  when :resources
    target.resources_build_phase
  end

  unless phase.files_references.any? { |r| r == ref }
    phase.add_file_reference(ref)
    puts "  + #{File.basename(path)}"
  else
    puts "  ✓ #{File.basename(path)} (already in phase)"
  end
  ref
end

# ── tvOS: add MyChannelTVApp.swift ───────────────────────────────────────────
puts "\n📺  Updating MyChannelTV target..."
tv_group = project['MyChannelTV'] || project.main_group.new_group('MyChannelTV', 'MyChannelTV')

tv_app_swift = File.expand_path('../MyChannelTV/MyChannelTVApp.swift', __dir__)
add_file(tv_group, tv_target, tv_app_swift, build_phase: :sources)

# tvOS Assets.xcassets
tv_assets = File.expand_path('../MyChannelTV/Assets.xcassets', __dir__)
tv_assets_ref = tv_group.files.find { |f| f.real_path.to_s == tv_assets }
tv_assets_ref ||= tv_group.new_file(tv_assets)
unless tv_target.resources_build_phase.files_references.any? { |r| r == tv_assets_ref }
  tv_target.resources_build_phase.add_file_reference(tv_assets_ref)
  puts "  + Assets.xcassets"
end

# Update tvOS build settings to point at the asset catalog
['Debug', 'Release'].each do |config|
  s = tv_target.build_settings(config)
  s['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'App Icon & Top Shelf Image'
  s['ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS'] = 'NO'
end
puts "  ⚙️  Asset catalog settings updated"

# ── watchOS: add Assets.xcassets ─────────────────────────────────────────────
puts "\n⌚️  Updating MyChannelWatch target..."
watch_group = project['MyChannelWatch'] || project.main_group.new_group('MyChannelWatch', 'MyChannelWatch')

watch_assets = File.expand_path('../MyChannelWatch/Assets.xcassets', __dir__)
watch_assets_ref = watch_group.files.find { |f| f.real_path.to_s == watch_assets }
watch_assets_ref ||= watch_group.new_file(watch_assets)
unless watch_target.resources_build_phase.files_references.any? { |r| r == watch_assets_ref }
  watch_target.resources_build_phase.add_file_reference(watch_assets_ref)
  puts "  + Assets.xcassets"
end

# Update watchOS build settings
['Debug', 'Release'].each do |config|
  s = watch_target.build_settings(config)
  s['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  s['ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS'] = 'NO'
end
puts "  ⚙️  Asset catalog settings updated"

# Also add the Info.plist to watchOS resources if missing
watch_plist = File.expand_path('../MyChannelWatch/Info.plist', __dir__)
watch_plist_ref = watch_group.files.find { |f| f.real_path.to_s == watch_plist }
watch_plist_ref ||= watch_group.new_file(watch_plist)

# ── iOS: add WatchConnectivityService.swift ──────────────────────────────────
puts "\n📱  Updating MyChannel (iOS) target..."
ios_target = project.targets.find { |t| t.name == 'MyChannel' }
if ios_target
  ios_watch_service = File.expand_path('../MyChannel/Core/Services/WatchConnectivityService.swift', __dir__)

  # Check if the file is already in the source phase (by path match)
  already_in_phase = ios_target.source_build_phase.files.any? do |bf|
    bf.file_ref && bf.file_ref.real_path.to_s == ios_watch_service rescue false
  end

  unless already_in_phase
    # Find the Core/Services group using recursive search
    core_services_group = nil
    project.main_group.recursive_children.each do |child|
      if child.is_a?(Xcodeproj::Project::Object::PBXGroup) &&
         child.real_path.to_s.end_with?('Core/Services')
        core_services_group = child
        break
      end
    end

    if core_services_group
      wc_ref = core_services_group.new_file(ios_watch_service)
      ios_target.source_build_phase.add_file_reference(wc_ref)
      puts "  + WatchConnectivityService.swift"
    else
      puts "  ⚠️  Core/Services group not found — WatchConnectivityService.swift already exists on disk; add it in Xcode"
    end
  else
    puts "  ✓ WatchConnectivityService.swift (already in build phase)"
  end
end

# ── Save ──────────────────────────────────────────────────────────────────────
project.save
puts "\n✅  Project updated successfully."
puts "   tvOS  → MyChannelTVApp.swift + Assets.xcassets added"
puts "   watch → Assets.xcassets added"
puts "   iOS   → WatchConnectivityService.swift added to source phase"

def find_or_create_group(parent, path)
  parts = path.split('/')
  parts.reduce(parent) do |grp, part|
    grp.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && c.name == part } ||
      grp.new_group(part)
  end
end
