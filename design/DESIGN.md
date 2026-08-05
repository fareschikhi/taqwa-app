---
name: Taqwa Management System
colors:
  surface: '#f6faf7'
  surface-dim: '#d7dbd8'
  surface-bright: '#f6faf7'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f1f5f1'
  surface-container: '#ebefeb'
  surface-container-high: '#e5e9e6'
  surface-container-highest: '#dfe3e0'
  on-surface: '#181d1b'
  on-surface-variant: '#3e4945'
  inverse-surface: '#2d312f'
  inverse-on-surface: '#eef2ee'
  outline: '#6e7a75'
  outline-variant: '#bdc9c3'
  surface-tint: '#006b57'
  primary: '#006b57'
  on-primary: '#ffffff'
  primary-container: '#7fd8be'
  on-primary-container: '#005f4d'
  inverse-primary: '#7ed7bd'
  secondary: '#146871'
  on-secondary: '#ffffff'
  secondary-container: '#a3ecf6'
  on-secondary-container: '#1b6c75'
  tertiary: '#43636b'
  on-tertiary: '#ffffff'
  tertiary-container: '#abcdd6'
  on-tertiary-container: '#38585f'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#9af4d9'
  primary-fixed-dim: '#7ed7bd'
  on-primary-fixed: '#002019'
  on-primary-fixed-variant: '#005141'
  secondary-fixed: '#a6eef9'
  secondary-fixed-dim: '#8ad2dc'
  on-secondary-fixed: '#001f23'
  on-secondary-fixed-variant: '#004f56'
  tertiary-fixed: '#c6e8f1'
  tertiary-fixed-dim: '#abccd5'
  on-tertiary-fixed: '#001f25'
  on-tertiary-fixed-variant: '#2b4b53'
  background: '#f6faf7'
  on-background: '#181d1b'
  surface-variant: '#dfe3e0'
typography:
  display-lg:
    fontFamily: Cairo
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 56px
  headline-lg:
    fontFamily: Cairo
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 44px
  headline-md:
    fontFamily: Cairo
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 34px
  headline-sm:
    fontFamily: Cairo
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Cairo
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Cairo
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-md:
    fontFamily: Tajawal
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Tajawal
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
  headline-lg-mobile:
    fontFamily: Cairo
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 38px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  2xl: 48px
  gutter: 20px
  margin-mobile: 16px
  margin-desktop: 40px
---

## Brand & Style

The design system is rooted in a **Modern SaaS** aesthetic that prioritizes clarity, focus, and a sense of "spiritual productivity." It avoids traditional clichés, opting instead for a "Linear-meets-Education" feel. The interface is characterized by generous whitespace, soft depth, and a layout that breathes, ensuring that the act of managing sacred knowledge feels organized and effortless.

The emotional response is one of **calm authority**. By utilizing large radii and a serene teal-based palette, the UI feels approachable yet highly professional. The "RTL-first" approach is not just a translation, but a structural foundation, where every element is mirrored to support the natural flow of the Arabic script.

## Colors

This design system uses a sophisticated teal spectrum to evoke growth and tranquility. 

- **Primary Gradient:** Used exclusively for high-impact actions, progress indicators, and brand-defining moments (e.g., student achievement badges).
- **Surface & Background:** A subtle distinction between `#F8FAFA` (app background) and pure `#FFFFFF` (content cards) creates a tiered visual hierarchy without the need for heavy lines.
- **Typography Colors:** Primary text uses a deep teal-black (`#12343B`) for maximum legibility, while secondary labels use a muted slate-teal (`#5C7277`) to maintain the monochromatic harmony.

## Typography

The typography system is **Arabic-first**, utilizing **Cairo** for its geometric clarity and structural reliability in headings. **Tajawal** is utilized for labels and UI elements where a slightly more condensed, modern grotesque feel is required to maximize screen real estate.

Line heights are intentionally generous to accommodate the diacritics (Tashkeel) of the Arabic script without overlapping. All type scales follow a 4px baseline grid to ensure vertical rhythm.

## Layout & Spacing

The layout is **RTL-only**, designed for right-to-left reading flow. It follows a **Mobile-First** philosophy where the primary navigation is accessible at the bottom of the screen on handheld devices.

- **Mobile:** Single column with 16px side margins. Content cards span the full width of the viewport minus margins.
- **Desktop:** A 12-column fluid grid. A persistent right-hand sidebar (280px width) handles navigation, with the main content area expanding dynamically.
- **Rhythm:** A consistent 8px-based spacing system is used to define the distance between related items (8px/16px) and unrelated sections (32px/48px).

## Elevation & Depth

This design system utilizes **Tonal Layering** combined with **Ambient Shadows** to create a premium feel. 

- **Level 0 (Background):** `#F8FAFA` – The base foundation.
- **Level 1 (Cards/Containers):** `#FFFFFF` – Pure white surfaces with a `0px 4px 20px rgba(18, 52, 59, 0.04)` shadow. This "whisper shadow" provides separation without visual noise.
- **Level 2 (Popovers/Modals):** Pure white with a more pronounced `0px 12px 32px rgba(18, 52, 59, 0.08)` shadow.
- **Interactive States:** On hover or focus, cards slightly lift (translate -2px) and the shadow opacity increases to 0.12.

## Shapes

The shape language is defined by **expansive, friendly radii**. 

- **Standard Elements:** Buttons and input fields use a **12px** radius.
- **Content Containers:** Main cards, student profiles, and progress modules use a **24px** radius (`rounded-xl` / `rounded-2xl`).
- **Contextual Elements:** Chips and small status tags use a **full pill** radius (100px).

This extreme roundedness differentiates the product from rigid enterprise software, signaling a modern, student-centric platform.

## Components

### Buttons
- **Primary:** Uses the brand gradient with white text. Height: 48px for mobile accessibility.
- **Secondary:** White background with a `#E7ECEC` border and `#1F6F78` text.
- **Tertiary:** No background or border; uses `#1F6F78` text for subtle actions.

### Input Fields
- Background is `#FFFFFF` with a 1px `#E7ECEC` border. On focus, the border transitions to `#7FD8BE` with a subtle outer glow. Placeholders are `#A0B1B5` in Tajawal.

### Progress Modules (SaaS Style)
- Circular progress indicators for Quran memorization using the primary gradient.
- High-contrast labels indicating "Juz," "Surah," or "Ayah" progress.

### Cards
- Always `#FFFFFF` with 24px padding and 24px border-radius. Avoid using dividers within cards; use 16px of vertical spacing instead.

### Chips & Badges
- Used for student status (Active, On Break, Completed). Backgrounds are 10% opacity of the status color with 100% opacity text of the same hue.