# Featured Card Video Standards

## 🎯 Design Requirements

All featured card videos **MUST** follow these standards to ensure visual consistency:

### 1. **Aspect Ratio: 16:9 (ENFORCED)**
- **Location**: `MinimalHeroSection.swift` line 177
- **Code**: `.aspectRatio(16/9, contentMode: .fit)`
- **Effect**: All videos are displayed in a consistent 16:9 container regardless of source video dimensions
- **Scaling**: Videos use `.scaledToFill()` to fill the container without letterboxing

### 2. **Play Button Overlay (ALWAYS VISIBLE)**
- **Location**: `FeaturedHeroCard.swift` bottom content section
- **Design**: 
  - White play icon + "Play" text
  - Black semi-transparent background (0.7 opacity)
  - 48pt height, full width
  - 12pt corner radius
- **Code**: Lines 139-152 in `FeaturedHeroCard.swift`

### 3. **Category Badge (TOP-LEFT)**
- **Location**: `FeaturedHeroCard.swift` top badges section
- **Design**:
  - Icon + category name (e.g., "⭐ Entertainment")
  - White text, 12pt semibold
  - Black semi-transparent capsule background (0.35 opacity)
  - 10pt horizontal padding, 6pt vertical padding
- **Code**: Lines 95-105 in `FeaturedHeroCard.swift`

### 4. **Duration Badge (TOP-RIGHT)**
- **Location**: `FeaturedHeroCard.swift` top badges section
- **Design**:
  - Time format (e.g., "0:35")
  - White text, 12pt semibold
  - Black background (0.75 opacity)
  - 6pt corner radius
- **Code**: Lines 109-115 in `FeaturedHeroCard.swift`

### 5. **Creator Info (BOTTOM-LEFT)**
- **Location**: `FeaturedHeroCard.swift` bottom content section
- **Design**:
  - Creator name with person icon
  - View count with eye icon
  - White text (0.9 opacity), 12pt semibold
  - Separated by "·" bullet
- **Code**: Lines 127-135 in `FeaturedHeroCard.swift`

### 6. **Watch Later Button (BOTTOM-RIGHT)**
- **Location**: `FeaturedHeroCard.swift` bottom content section
- **Design**:
  - "+" icon (or checkmark if saved)
  - White background with subtle shadow
  - 48x48pt square
  - 12pt corner radius
- **Code**: Lines 154-171 in `FeaturedHeroCard.swift`

## 📁 Key Files

1. **`MinimalHeroSection.swift`**
   - Controls the featured carousel container
   - **Enforces 16:9 aspect ratio** for all cards
   - Handles auto-scroll and pagination dots

2. **`FeaturedHeroCard.swift`**
   - Individual card component
   - Contains all overlay elements (badges, buttons, text)
   - Handles video preview playback

3. **`FeaturedUIKitCarousel.swift`**
   - UIKit-based horizontal paging carousel
   - Manages card swiping and selection

4. **`FeaturedHeroPoster.swift`**
   - Thumbnail/poster image component
   - Uses `.scaledToFill()` to fill 16:9 container

## ✅ Checklist for Adding New Featured Videos

When adding a new video to the featured section:

- [ ] Video will automatically be displayed in 16:9 aspect ratio
- [ ] Play button overlay will automatically appear
- [ ] Category badge will automatically show (from video.category)
- [ ] Duration badge will automatically show (from video.formattedDuration)
- [ ] Creator name will automatically show (from video.creator.displayName)
- [ ] View count will automatically show (from video.formattedViewCount)
- [ ] Watch Later button will automatically appear

**No manual configuration needed!** All elements are automatically rendered for every video added to the featured section.

## 🎨 Visual Consistency

The system ensures:
- ✅ All cards have identical dimensions (16:9 ratio)
- ✅ All cards have the same overlay elements in the same positions
- ✅ All text uses consistent fonts, sizes, and colors
- ✅ All buttons have consistent styling and behavior
- ✅ All videos fill the container without distortion

## 🔧 How to Add Videos to Featured Section

### For Admins:
1. Open the app
2. Go to Home tab
3. Tap "Edit" button in the Featured section header
4. Select up to 3 videos to feature
5. Videos will automatically display with all required elements

### Programmatically:
```swift
// Videos are managed through FeaturedStore
FeaturedStore.shared.addFeaturedVideo(video)
```

## 📊 Current Implementation Status

✅ **COMPLETE** - All featured cards have:
- Consistent 16:9 aspect ratio
- Play button overlay
- Category badge (top-left)
- Duration badge (top-right)
- Creator info (bottom-left)
- Watch Later button (bottom-right)

No additional work needed! The system is fully implemented and enforced.
