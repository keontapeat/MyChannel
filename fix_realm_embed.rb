require 'xcodeproj'

project_path = '/Users/keonta/Documents/MyChannel/MyChannel.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'MyChannel' }

# Find or create the Embed Frameworks phase
embed_phase = target.build_phases.find { |p| p.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase) && p.name == 'Embed Frameworks' }
unless embed_phase
  embed_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
  embed_phase.name = 'Embed Frameworks'
  embed_phase.dst_subfolder_spec = '10'  # Frameworks
  target.build_phases << embed_phase
  puts "Created Embed Frameworks phase"
end

# Find RealmSwift and Realm package product dependencies
realm_products = target.package_product_dependencies.select { |d|
  d.product_name =~ /Realm/i
}

puts "Found #{realm_products.count} Realm product(s): #{realm_products.map(&:product_name).join(', ')}"

realm_products.each do |dep|
  already_embedded = embed_phase.files.any? { |f|
    f.product_ref&.product_name == dep.product_name rescue false
  }
  if already_embedded
    puts "  ~ already embedded: #{dep.product_name}"
  else
    bf = project.new(Xcodeproj::Project::Object::PBXBuildFile)
    bf.product_ref = dep
    bf.settings = { 'ATTRIBUTES' => ['CodeSignOnCopy', 'RemoveHeadersOnCopy'] }
    embed_phase.files << bf
    puts "  + embedded: #{dep.product_name}"
  end
end

project.save
puts "Done."
