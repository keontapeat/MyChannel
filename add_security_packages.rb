require 'xcodeproj'

project_path = '/Users/keonta/Documents/MyChannel/MyChannel.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'MyChannel' }
frameworks_phase = target.frameworks_build_phase

packages = [
  { url: 'https://github.com/securing/IOSSecuritySuite', version: '1.9.0', product: 'IOSSecuritySuite' },
  { url: 'https://github.com/datatheorem/TrustKit',      version: '3.0.0', product: 'TrustKit'         },
]

packages.each do |pkg|
  pkg_ref = project.root_object.package_references.find { |r| r.repositoryURL == pkg[:url] }
  unless pkg_ref
    pkg_ref = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
    pkg_ref.repositoryURL = pkg[:url]
    pkg_ref.requirement = { 'kind' => 'upToNextMajorVersion', 'minimumVersion' => pkg[:version] }
    project.root_object.package_references << pkg_ref
    puts "  + package: #{pkg[:url]}"
  else
    puts "  ~ exists:  #{pkg[:url]}"
  end

  next if target.package_product_dependencies.any? { |d| d.product_name == pkg[:product] }

  dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dep.package = pkg_ref
  dep.product_name = pkg[:product]
  target.package_product_dependencies << dep

  bf = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  bf.product_ref = dep
  frameworks_phase.files << bf
  puts "  + linked:  #{pkg[:product]}"
end

project.save
puts "\nDone."
