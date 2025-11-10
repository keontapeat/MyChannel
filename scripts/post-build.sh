#!/bin/bash

# Post-Build Script - Runs after each Xcode build

if [ "${ACTION}" = "build" ]; then
    if [ "${BUILD_SUCCEEDED}" = "NO" ]; then
        echo "❌ Build Failed - marking for DerivedData cleanup"
        touch /tmp/mychannel_build_failed
    else
        echo "✅ Build Succeeded"
        rm -f /tmp/mychannel_build_failed
    fi
fi


