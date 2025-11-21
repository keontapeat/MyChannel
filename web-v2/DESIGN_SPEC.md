# MyChannel Design Specification

## 🎨 Design System Overview

**Brand**: MyChannel - Bold, Premium, Creator-First  
**URL**: https://www.mychannel.live  
**Tone**: Professional, modern, empowering

---

## 🎯 Design Principles

1. **YouTube-Level Quality**: Match YouTube's polish and professionalism
2. **Mobile-First**: Design for mobile, enhance for desktop
3. **Accessibility First**: WCAG 2.1 AA compliant from day one
4. **Performance**: Fast, smooth, responsive
5. **Creator-Centric**: Empower creators with premium tools

---

## 🎨 Color Palette

### Primary Colors
- **Primary**: `#0ea5a3` (Emerald/Teal) - Brand color
- **Primary Hover**: `#0d9488` - Hover state
- **Accent**: `#ff0044` - CTAs, highlights

### Neutral Colors (Light Mode)
- **Background**: `#ffffff` - Pure white
- **Surface**: `#f9f9f9` - Cards, inputs
- **Border**: `#e5e5e5` - Subtle borders
- **Text Primary**: `#0f0f0f` - True black
- **Text Secondary**: `#606060` - Medium gray
- **Text Tertiary**: `#888888` - Light gray

### Neutral Colors (Dark Mode)
- **Background**: `#0f0f0f` - True black
- **Surface**: `#212121` - Charcoal
- **Border**: `#303030` - Dark gray
- **Text Primary**: `#ffffff` - Pure white
- **Text Secondary**: `#aaaaaa` - Light gray
- **Text Tertiary**: `#888888` - Medium gray

### Semantic Colors
- **Success**: `#2e7d32` (Green)
- **Warning**: `#ff9800` (Orange)
- **Error**: `#d32f2f` (Red)

---

## 📐 Typography

### Font Families
- **UI Font**: `-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif`
- **Display Font**: `'Playfair Display', serif` (Headlines)
- **Mono Font**: `'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, monospace`

### Font Sizes
- **xs**: 11px - Tiny labels
- **sm**: 12px - Captions, metadata
- **base**: 14px - Body text
- **md**: 16px - Titles
- **lg**: 18px - Headings
- **xl**: 20px - Large headings
- **2xl**: 24px - Section headings
- **3xl**: 30px - Hero headings
- **4xl**: 36px - Large hero headings

### Font Weights
- **Regular**: 400
- **Medium**: 500
- **Semibold**: 600
- **Bold**: 700

### Line Heights
- **Tight**: 1.2 (Titles)
- **Snug**: 1.375 (Compact text)
- **Normal**: 1.5 (Body text)
- **Relaxed**: 1.625 (Spacious text)

---

## 📏 Spacing System

4px base unit system:

- **xs**: 4px
- **sm**: 8px
- **md**: 16px
- **lg**: 24px
- **xl**: 32px
- **2xl**: 48px
- **3xl**: 64px

---

## 🔲 Border Radius

- **sm**: 6px
- **md**: 8px
- **lg**: 12px
- **xl**: 16px
- **full**: 9999px (Pills)

---

## 📱 Breakpoints

- **Mobile**: 375px+
- **Tablet**: 768px+
- **Desktop**: 1024px+
- **Wide**: 1440px+

---

## 🎭 Component Specifications

### Header
- **Height**: 56px (14 * 4px)
- **Background**: White (light) / Black (dark)
- **Border**: Bottom border, subtle
- **Logo**: 32x32px, rounded-lg
- **Search**: Rounded-full, max-width 640px
- **Icons**: 18-20px, consistent spacing

### Hero
- **Min Height**: 600px (mobile), 700px (tablet), 800px (desktop)
- **Background**: Video (desktop) / Image (mobile)
- **Overlay**: Gradient from black/60 to black/80
- **Title**: 4xl-7xl font size, bold, white
- **Subtitle**: lg-2xl font size, white/90
- **CTAs**: Rounded-full, primary/accent colors
- **Stats**: Cards with backdrop blur, white/10 background

### VideoCard
- **Aspect Ratio**: 16:9 (aspect-video)
- **Border Radius**: xl (12px)
- **Thumbnail**: Object-cover, lazy loaded
- **Duration Badge**: Bottom-right, black/90 background
- **Title**: sm font, semibold, line-clamp-2
- **Channel**: xs font, secondary color
- **Metadata**: xs font, tertiary color
- **Hover**: Scale thumbnail 1.05, translateY -2px

### Button
- **Primary**: Primary color background, white text, rounded-full
- **Secondary**: Surface background, primary text, rounded-full
- **Outline**: Transparent, border, rounded-full
- **Sizes**: sm (px-4 py-2), md (px-6 py-3), lg (px-8 py-4)
- **Hover**: Scale 1.05, shadow increase
- **Focus**: Ring 4px, primary color

---

## 🎬 Animations

### Duration
- **Fast**: 150ms
- **Normal**: 200ms
- **Slow**: 300ms

### Easing
- **Standard**: `cubic-bezier(0.4, 0, 0.2, 1)`
- **Ease Out**: `cubic-bezier(0, 0, 0.2, 1)`
- **Ease In**: `cubic-bezier(0.4, 0, 1, 1)`

### Common Animations
- **Fade In**: Opacity 0 → 1
- **Fade In Up**: Opacity 0 → 1, translateY 20px → 0
- **Scale**: Scale 1 → 1.05 (hover)
- **Slide**: translateX/Y transitions

---

## 🖼️ Images

### Formats
- **Primary**: WebP (with JPEG fallback)
- **Future**: AVIF (when supported)
- **Placeholder**: LQIP (Low Quality Image Placeholder)

### Sizes
- **Thumbnail**: 640x360 (16:9)
- **Hero Background**: 1920x1080
- **Avatar**: 40x40px (rounded-full)
- **Logo**: 32x32px (rounded-lg)

### Optimization
- Lazy loading for below-fold images
- Responsive srcset for different screen sizes
- Blur placeholder during load

---

## 📐 Layout Grids

### Landing Page
- **Mobile**: 1 column
- **Tablet**: 2 columns
- **Desktop**: 3-4 columns
- **Wide**: 5-6 columns

### Watch Page
- **Mobile**: Full width video, stacked info
- **Desktop**: Video left (2/3), sidebar right (1/3)

---

## 🎯 Figma File Structure

### Pages
1. **Landing** (Desktop + Mobile)
2. **Watch** (Desktop + Mobile)
3. **Channel** (Desktop + Mobile)

### Components
- Header
- Hero
- VideoCard
- Button
- Input
- Card

### Design Tokens
- Colors
- Typography
- Spacing
- Shadows
- Border Radius

---

## ✅ Design Checklist

### Landing Page
- [x] Header with logo, search, user menu
- [x] Hero section with title, subtitle, CTAs
- [x] Stats display (3 cards)
- [x] Video grid (responsive)
- [x] Footer (if needed)

### Watch Page
- [x] Video player (16:9 aspect)
- [x] Video title and metadata
- [x] Channel info and subscribe button
- [x] Description (expandable)
- [x] Comments section
- [x] Related videos sidebar

### Responsive
- [x] Mobile layout (375px)
- [x] Tablet layout (768px)
- [x] Desktop layout (1024px)
- [x] Wide layout (1440px)

---

## 📋 Design Deliverables

1. ✅ **Design Tokens JSON** (`design-tokens.json`)
2. ✅ **Component Specifications** (This document)
3. ⏳ **Figma File** (To be created/exported)
4. ✅ **Storybook Stories** (Component examples)

---

## 🎨 Brand Guidelines

### Logo Usage
- Minimum size: 32x32px
- Clear space: 2x logo width
- Never distort or rotate
- Use on light or dark backgrounds

### Color Usage
- Primary color: Use sparingly (buttons, links, active states)
- Accent color: CTAs, highlights, important actions
- Neutral grays: 90% of UI should be grays/whites

### Typography Usage
- Headlines: Playfair Display (when available), otherwise system bold
- Body: System font stack
- Code: Mono font stack

---

**Design System Version**: 1.0  
**Last Updated**: 2024-12-19



