require 'xcodeproj'
project_path = 'MyChannel.xcodeproj'
project = Xcodeproj::Project.open(project_path)

['https://github.com/shogo4405/HaishinKit.swift'].each do |url|
  project.root_object.package_references.each do |pkg|
    if pkg.repositoryURL == url
      puts "Found #{url}, removing..."
      pkg.remove_from_project
    end
  end

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
