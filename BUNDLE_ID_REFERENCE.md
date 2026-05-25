# App Store Bundle ID Reference

## ⚠️ CRITICAL: Do Not Change

The bundle identifier for this app is locked to the App Store Connect record.

### Current Bundle ID
```
com.keontapeat.MyChannelApp
```

### Why This Matters
- App Store Connect app record: **MyChannel.live**
- Bundle ID in ASC: `com.keontapeat.MyChannelApp`
- Changing this in Xcode will break archiving/distribution
- Apple does not allow bundle ID changes once an app is created

### If You See This Error
> "App record with bundle identifier was previously removed from App Store Connect"

**Cause:** Xcode bundle ID doesn't match App Store Connect

**Fix:**
1. Open `MyChannel.xcodeproj`
2. Select target → Build Settings
3. Find `PRODUCT_BUNDLE_IDENTIFIER`
4. Ensure it is: `com.keontapeat.MyChannelApp`

### Validation Script
`scripts/validate-bundle-id.sh` runs during build to catch mismatches

### Last Verified
- Date: 2026-03-27
- ASC App: MyChannel.live
- Status: 1.0 Rejected (awaiting resubmission)
