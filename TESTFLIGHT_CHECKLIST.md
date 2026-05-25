# TestFlight Setup Checklist for MyChannel

## ✅ Completed (by script)
- [x] Enabled push notifications in entitlements
- [x] Enabled associated domains in entitlements  
- [x] Enabled background modes in Info.plist
- [x] Set proper version (1.0) and build number (1)
- [x] Created build script for TestFlight

## 🔧 Manual Steps in Xcode

### 1. Update Development Team (CRITICAL)
1. Open `MyChannel.xcodeproj` in Xcode
2. Select the project in the navigator
3. Under "Signing & Capabilities" for both Debug and Release:
   - Set **Team** to your new Apple Developer account
   - Verify **Bundle Identifier** is `com.keontapeat.MyChannel`
   - Ensure **Automatically manage signing** is checked

### 2. Add Required Capabilities
1. In "Signing & Capabilities" tab, click the **+ Capability** button and add:
   - [x] **Push Notifications** capability
   - [x] **Associated Domains** capability  
   - [x] **Background Modes** capability
   - [x] **Sign In with Apple** capability ⭐ **NEW**

2. Configure each capability:
   - **Associated Domains**: Add `applinks:mychannel.live` and `applinks:www.mychannel.live`
   - **Background Modes**: Enable "Background fetch" and "Remote notifications"
   - **Sign In with Apple**: Should be automatically configured

### 3. Check Provisioning Profile
1. Make sure Xcode can create/download the provisioning profile
2. If you see signing errors, try:
   - Product → Clean Build Folder
   - Xcode → Preferences → Accounts → Download Manual Profiles
   - Toggle "Automatically manage signing" off and on again

## 🚀 Building for TestFlight

### Option 1: Using the Build Script (Recommended)
```bash
cd /Users/keonta/Documents/MyChannel
./build-for-testflight.sh
```

### Option 2: Manual Xcode Build
1. In Xcode: Product → Archive
2. When archive completes, Organizer opens
3. Select your archive → "Distribute App"
4. Choose "App Store Connect"
5. Follow the upload wizard

## 📱 After Upload

### In App Store Connect (https://appstoreconnect.apple.com)
1. Go to "My Apps" → MyChannel
2. Click "TestFlight" tab
3. Wait for processing (can take 10-30 minutes)
4. Add internal testers (up to 100, no review needed)
5. Add external testers (unlimited, requires Apple review)

### Adding Testers
- **Internal**: Add by Apple ID email, immediate access
- **External**: Submit for beta review first (1-3 days)

## 🔍 Common Issues & Solutions

### Signing Issues
- Ensure your Apple ID is added in Xcode → Preferences → Accounts
- Try toggling "Automatically manage signing" off and on
- Clean build folder and try again
- **Apple Sign In errors**: Make sure you've added the "Sign In with Apple" capability in Xcode

### Upload Issues
- Check bundle ID matches App Store Connect
- Ensure version/build number is higher than previous uploads
- Verify all required capabilities are properly configured

### TestFlight Processing
- Processing can take 10-30 minutes after upload
- Check for email notifications about processing status
- If stuck, try uploading a new build with incremented build number

## 📞 Need Help?
- Check Xcode's Report Navigator for detailed error messages
- Visit Apple Developer Forums for community support
- Review Apple's TestFlight documentation
