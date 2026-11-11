---
name: Taqwa Parent Portal
colors:
  surface: '#f0fdeb'
  surface-dim: '#d0decc'
  surface-bright: '#f0fdeb'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eaf8e5'
  surface-container: '#e4f2e0'
  surface-container-high: '#dfecda'
  surface-container-highest: '#d9e6d4'
  on-surface: '#131e13'
  on-surface-variant: '#3e4a39'
  inverse-surface: '#283327'
  inverse-on-surface: '#e7f5e2'
  outline: '#6e7b68'
  outline-variant: '#bdcbb5'
  surface-tint: '#006e00'
  primary: '#006c00'
  on-primary: '#ffffff'
  primary-container: '#008800'
  on-primary-container: '#f8ffef'
  inverse-primary: '#68e054'
  secondary: '#006b57'
  on-secondary: '#ffffff'
  secondary-container: '#97f4d9'
  on-secondary-container: '#00725d'
  tertiary: '#546204'
  on-tertiary: '#ffffff'
  tertiary-container: '#6c7b20'
  on-tertiary-container: '#fcffe0'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#84fd6e'
  primary-fixed-dim: '#68e054'
  on-primary-fixed: '#002200'
  on-primary-fixed-variant: '#005300'
  secondary-fixed: '#97f4d9'
  secondary-fixed-dim: '#7bd7bd'
  on-secondary-fixed: '#002019'
  on-secondary-fixed-variant: '#005141'
  tertiary-fixed: '#d9ec84'
  tertiary-fixed-dim: '#becf6b'
  on-tertiary-fixed: '#181e00'
  on-tertiary-fixed-variant: '#404c00'
  background: '#f0fdeb'
  on-background: '#131e13'
  surface-variant: '#d9e6d4'
typography:
  headline-xl:
    fontFamily: Cairo
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 44px
  headline-lg:
    fontFamily: Cairo
    fontSize: 26px
    fontWeight: '700'
    lineHeight: 38px
  headline-md:
    fontFamily: Cairo
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 30px
  headline-sm:
    fontFamily: Cairo
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Tajawal
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 26px
  body-md:
    fontFamily: Tajawal
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 22px
  body-sm:
    fontFamily: Tajawal
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 18px
  label-lg:
    fontFamily: Tajawal
    fontSize: 14px
    fontWeight: '700'
    lineHeight: 20px
  label-md:
    fontFamily: Tajawal
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
  label-sm:
    fontFamily: Tajawal
    fontSize: 10px
    fontWeight: '500'
    lineHeight: 14px
  numeral-hero:
    fontFamily: Cairo
    fontSize: 36px
    fontWeight: '700'
    lineHeight: 44px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.25rem
  space-xl: 1.5rem
---

## Brand & Style

This design system establishes a calm, trustworthy, and spiritually uplifting mobile environment tailored for Quran school administration and parent engagement. It bridges sacred educational duty with contemporary mobile ergonomics.

### Emotional Signature
- **Veneration & Calmness:** Grounded green tones evoke peace, discipline, and growth.
- **Clarity & Trust:** Structural lucidity, legible Arabic typography, and unambiguous progress tracking instill institutional credibility.
- **Warmth & Encouragement:** Subtle warm-gold accents celebrate student milestones without gamifying spiritual learning.

### Design Aesthetic
The aesthetic balances **Modern Minimalism** with **Soft Tactility**:
- Strictly designed for Right-to-Left (RTL) reading hierarchy.
- Flat surfaces elevated with subtle ambient greenish diffusion and feather-light borders.
- Generous internal padding and breathable layout rhythms to prevent visual fatigue during grade, attendance, and recitation reviews.

## Colors

The palette is anchored in nature, balance, and scholarly focus. Every color token maps to a specific functional role to ensure consistent parent comprehension.

### Core Palette
- **Primary (`#009000`):** Used for hero performance cards, filled action triggers, active navigation items, progress rings, and key metric indicators.
- **Primary-Dark (`#006B00`):** Applied to interactive links on white surfaces and pressed button states to guarantee WCAG AAA legibility.
- **Primary-Soft (`#E6F4E6`):** Tint surface for tags, badge backgrounds, and selected navigational pills, paired with `#005A00` text.
- **Secondary (`#0E7C66` / Teal-Green):** Categorization of New Memorization (الحفظ الجديد).
- **Tertiary (`#66751A` / Olive):** Categorization of Revision & Consolidation (المراجعة والتثبيت).

### Canvas & Surface Tokens
- **Canvas Base:** `#F5F8F5` (Soft pale sage-tinted neutral to reduce glare).
- **Surface Elevation (Cards):** `#FFFFFF`.
- **Card Outline:** 1px solid `#E3EAE3`.
- **Primary Body Text:** `#152015`.
- **Secondary Supporting Text:** `#5A6A5A`.

### Status & Categorical Tones
- **Attendance - Present:** `#009000`
- **Attendance - Late:** `#B26A00`
- **Attendance - Excused:** `#1F6FB2`
- **Attendance - Absent:** `#C62828`
- **Honor Accent (Student of the Month):** `#C9A227` (Lustrous Gold)

## Typography

The typographic system utilizes **Cairo** for structural headlines, scores, Ayah counts, and numerals, delivering architectural strength and balanced Arabic letterforms. **Tajawal** serves as the primary reading face for its open counters, humanist curves, and high legibility across small viewport densities.

### Rules & Hierarchy
- **Strict RTL Alignment:** Text aligns right by default. Directional punctuation and numeral placements adhere to Eastern Arabic or standardized Arabic layout standards.
- **Metrics & Numbers:** Recitation statistics, Juz counts, and grade percentages use `Cairo Bold` to preserve authoritative impact.
- **Reading Comfort:** Arabic scripts require higher vertical clearance than Latin fonts; line-heights are explicitly scaled to avoid overlapping ascenders and diacritics (Tashkeel).

## Layout & Spacing

A disciplined 4px base spatial unit optimizes vertical rhythms for compact mobile screens while preserving an open, serene feel.

### Form Factor Behavior
- **Screen Margins:** Standard mobile canvas padding is anchored at `1rem` (16px) horizontally to maximize actionable screen real estate.
- **Content Stacking:** Cards and distinct informational groups maintain a `1rem` vertical gap.
- **Inner Padding:** Cards utilize `1.25rem` (20px) internal breathing space to avoid visual crowding alongside right-aligned typography.
- **RTL Fluidity:** Margin-inline and padding-inline tokens must replace static left/right values to automatically accommodate RTL orientations.

## Elevation & Depth

Visual hierarchy uses a crisp, non-skeuomorphic layering model: clean white planes resting slightly above the muted sage canvas (`#F5F8F5`).

### Depth Tiers
- **Base Canvas:** Flat `#F5F8F5`, zero elevation.
- **Cards & Content Surfaces:** `#FFFFFF` background bound by a 1px continuous hairline outline of `#E3EAE3` and lifted by an ambient shadow:
  - `box-shadow: 0 4px 16px rgba(0, 40, 0, 0.06)`
- **Modals & Bottom Drawers:** Raised above a softened dark veil (`rgba(21, 32, 21, 0.4)`), using an elevated ambient shadow:
  - `box-shadow: 0 -8px 24px rgba(0, 40, 0, 0.10)`
- **Active Navigation Pill / Tonal Surface:** Completely flat, relying on `#E6F4E6` contrast without shadow displacement.

## Shapes

The geometric identity balances modern precision with friendly, child-centered warmth through custom corner radiuses:

- **Cards & Containers:** `20px` corner radius.
- **Interactive Buttons:** `14px` corner radius.
- **Pills, Badges & Nav Indicators:** Fully rounded (`9999px` / circular).
- **Icons:** Rounded visual endpoints via *Material Symbols Rounded*.

## Components

### Buttons
- **Primary Filled:** Background `#009000`, text `#FFFFFF`, radius `14px`, height `48px`, font `label-lg`. Active/Pressed state shifts to `#006B00`.
- **Secondary Tonal:** Background `#E6F4E6`, text `#005A00`, radius `14px`, height `48px`.
- **Outline / Ghost:** 1px border `#E3EAE3`, text `#152015`.

### Chips & Badges
- **Memorization Type Pills:**
  - *New Memorization (الحفظ الجديد):* Background `rgba(14, 124, 102, 0.12)`, text `#0E7C66`.
  - *Revision (المراجعة):* Background `rgba(102, 117, 26, 0.12)`, text `#66751A`.
- **Attendance Badges:** Fully rounded (`9999px`), padding `4px 12px`, font `label-sm`:
  - *Present (حاضر):* `#E6F4E6` background, `#009000` text.
  - *Late (متأخر):* `rgba(178, 106, 0, 0.12)` background, `#B26A00` text.
  - *Excused (معذور):* `rgba(31, 111, 178, 0.12)` background, `#1F6FB2` text.
  - *Absent (غائب):* `rgba(198, 40, 40, 0.12)` background, `#C62828` text.

### Cards
- **Standard Card:** Surface `#FFFFFF`, border `1px solid #E3EAE3`, corner radius `20px`, shadow `0 4px 16px rgba(0, 40, 0, 0.06)`. Internal padding `20px`.
- **Hero Progress Card:** Solid `#009000` or subtle dual-tone gradient into `#007A00`, text `#FFFFFF`, displaying overall Surah completion, current Hizb, and active streak.
- **Student of the Month Card:** Border tinted with `1px solid #C9A227`, housing a soft gold badge accent (`#C9A227`) alongside a Quranic icon.

### Input Fields
- **Container:** Height `52px`, background `#FFFFFF`, border `1px solid #E3EAE3`, radius `14px`, right-aligned text `#152015`, placeholder `#5A6A5A`.
- **Focus State:** 1.5px solid outline in `#009000`, slight `#009000` tint ring (`rgba(0, 144, 0, 0.1)`).

### Lists & Activity Feeds
- **Daily Recitation Item:** White row container, divider `1px solid #F0F4F0`, leading timestamp / Ayah counter in `Cairo`, trailing teacher evaluation chip.
- **Iconography:** System icons strictly drawn from *Material Symbols Rounded*, sized `20px` or `24px`, inheriting `#009000` or `#5A6A5A`.