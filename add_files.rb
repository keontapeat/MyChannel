require 'xcodeproj'
project_path = 'MyChannel.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

group = project.main_group.find_subpath(File.join('MyChannel', 'Core', 'Services'), true)

files_to_add = [
  'MyChannel/Core/Services/NVIDIABroadcastService.swift',
  'MyChannel/Core/Services/EdgeImagePrefetcher.swift'
]

files_to_add.each do |file_path|
  file_ref = group.new_reference(File.basename(file_path))
  target.add_file_references([file_ref])
end

project.save
puts 'Successfully added files to Xcode project'
