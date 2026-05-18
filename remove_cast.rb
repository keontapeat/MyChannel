require 'xcodeproj'

project_path = 'MyChannel.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find and remove the CastVideos-ios package reference
project.root_object.package_references.each do |pkg|
  if pkg.repositoryURL == 'https://github.com/googlecast/CastVideos-ios'
    puts "Found CastVideos-ios, removing..."
    pkg.remove_from_project
  end
end

# Remove the CastVideos package product dependencies from all targets
project.targets.each do |target|
  target.package_product_dependencies.each do |dep|
    if dep.package.nil? || dep.package.repositoryURL == 'https://github.com/googlecast/CastVideos-ios'
      puts "Removing product dependency from #{target.name}"
      dep.remove_from_project
    end
  end
end

project.save
puts "Successfully removed CastVideos-ios!"
