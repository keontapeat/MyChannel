# MyChannel Web V2

Production-ready Next.js frontend for MyChannel - a next-generation video platform combining YouTube + Twitch + DraftKings + UFC.

## 🚀 Quick Start

### Prerequisites

- Node.js 18+ 
- npm or yarn

### Installation

```bash
npm install
```

### Development

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

### Build for Production

```bash
npm run build
npm start
```

## 📁 Project Structure

```
web-v2/
├── app/                    # Next.js App Router pages
│   ├── page.tsx           # Landing page
│   ├── watch/[id]/        # Watch page (dynamic route)
│   ├── layout.tsx         # Root layout
│   └── globals.css        # Global styles
├── components/             # React components
│   ├── layout/            # Header, Hero, Sidebar
│   ├── video/             # VideoCard, VideoPlayer
│   └── ui/                # Button, Card (reusable)
├── lib/                    # Utilities & services
│   ├── firebase/          # Firebase integration
│   └── utils/             # Helper functions
├── tests/                  # E2E tests (Playwright)
│   └── e2e/
├── design-tokens.json     # Design system tokens
└── public/                # Static assets
```

## 🎨 Design System

Design tokens are defined in `design-tokens.json`:

- **Colors**: Primary (#0ea5a3), Accent (#ff0044), semantic colors
- **Typography**: Inter (UI), Playfair Display (headlines)
- **Spacing**: 4px base unit system
- **Breakpoints**: 375px (mobile), 768px (tablet), 1024px (desktop), 1440px (wide)

## 🧪 Testing

### E2E Tests (Playwright)

```bash
# Run all tests
npm test

# Run in UI mode
npm run test:ui

# Run in headed mode (see browser)
npm run test:headed
```

### Storybook (Component Development)

```bash
# Start Storybook
npm run storybook

# Build Storybook
npm run build-storybook
```

Open [http://localhost:6006](http://localhost:6006) to view components.

## 📦 Key Components

### Header
- YouTube-level navigation bar
- Search with keyboard shortcuts ('/' to focus)
- User menu and notifications
- Fully accessible (ARIA labels, keyboard navigation)

### Hero
- Premium landing section
- Video background support
- Responsive stats display
- Smooth animations (Framer Motion)

### VideoCard
- YouTube-style video card
- Hover effects and animations
- Lazy loading images
- Accessible and keyboard navigable

## 🔧 Tech Stack

- **Framework**: Next.js 15 (App Router)
- **Language**: TypeScript
- **Styling**: Tailwind CSS 4
- **Animations**: Framer Motion
- **Testing**: Playwright (E2E), Storybook (Components)
- **Deployment**: Firebase Hosting (Static Export)

## 📱 Responsive Design

- **Mobile**: 375px+ (mobile-first)
- **Tablet**: 768px+
- **Desktop**: 1024px+
- **Wide**: 1440px+

All components are mobile-first and fully responsive.

## ♿ Accessibility

- WCAG 2.1 AA compliant
- Semantic HTML
- ARIA labels and roles
- Keyboard navigation support
- Focus management
- Screen reader friendly

## 🚀 Deployment

### Firebase Hosting

```bash
npm run deploy
```

This will:
1. Copy logo assets
2. Build Next.js static export
3. Deploy to Firebase Hosting

### Environment Variables

Create `.env.local`:

```bash
NEXT_PUBLIC_FIREBASE_API_KEY=your_key
NEXT_PUBLIC_FIREBASE_PROJECT_ID=your_project_id
# ... other Firebase config
```

## 📊 Performance

Target metrics:
- **Lighthouse**: 85+ (desktop baseline)
- **First Contentful Paint**: < 1.8s
- **Largest Contentful Paint**: < 2.5s
- **Time to Interactive**: < 3.8s

Optimizations:
- Static export for fast loading
- Image optimization (lazy loading, responsive images)
- Code splitting (automatic with Next.js)
- Font optimization

## 🔍 SEO

- Server-rendered meta tags
- Open Graph tags
- JSON-LD structured data (VideoObject)
- Semantic HTML
- Sitemap generation
- robots.txt

## 📝 Code Style

- ESLint + Prettier configured
- TypeScript strict mode
- Semantic commit messages
- Component documentation (JSDoc)

## 🐛 Known Issues

See [ISSUES.md](./ISSUES.md) for current issues and planned improvements.

## 📄 License

Private - MyChannel Platform

## 🤝 Contributing

1. Create feature branch
2. Make changes
3. Run tests (`npm test`)
4. Submit PR

---

**Built with ❤️ for creators**
