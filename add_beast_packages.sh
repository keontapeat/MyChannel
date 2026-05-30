#!/bin/bash
set -e

SPM_TOOL="/Users/keonta/.gemini/config/plugins/firebase/skills/xcode_project_setup/scripts/xcode_spm_setup"
PROJECT="MyChannel.xcodeproj"

echo "Adding LiveKit..."
swift run --package-path "$SPM_TOOL" xcode_spm_setup "$PROJECT" https://github.com/livekit/client-sdk-swift 2.14.1 LiveKit

echo "Adding Texture..."
swift run --package-path "$SPM_TOOL" xcode_spm_setup "$PROJECT" https://github.com/TextureGroup/Texture 3.1.0 AsyncDisplayKit

echo "Adding FFmpegKit..."
swift run --package-path "$SPM_TOOL" xcode_spm_setup "$PROJECT" https://github.com/arthenica/ffmpegkit 6.0.0 ffmpegkit

echo "Adding CoreMLHelpers..."
swift run --package-path "$SPM_TOOL" xcode_spm_setup "$PROJECT" https://github.com/hollance/CoreMLHelpers 1.0.0 CoreMLHelpers

echo "All Done!"
