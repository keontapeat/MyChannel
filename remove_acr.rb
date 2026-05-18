require 'xcodeproj'

project_path = 'MyChannel.xcodeproj'
project = Xcodeproj::Project.open(project_path)

['https://github.com/acrcloud/acrcloud_sdk_ios', 'https://github.com/BradLarson/GPUImage3'].each do |url|
  # Find and remove the package reference
  project.root_object.package_references.each do |pkg|
    if pkg.repositoryURL == url
      puts "Found #{url}, removing..."
      pkg.remove_from_project
    end
  end

  # Remove the package product dependencies from all targets
  project.targets.each do |target|
    target.package_product_dependencies.each do |dep|
      if dep.package.nil? || dep.package.repositoryURL == url
        puts "Removing product dependency for #{url} from #{target.name}"
        dep.remove_from_project
      end
    end
  end
end

project.save
puts "Successfully removed invalid SPM packages!"
