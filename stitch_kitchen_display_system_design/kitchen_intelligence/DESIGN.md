---
name: Kitchen Intelligence
colors:
  surface: '#0b1326'
  surface-dim: '#0b1326'
  surface-bright: '#31394d'
  surface-container-lowest: '#060e20'
  surface-container-low: '#131b2e'
  surface-container: '#171f33'
  surface-container-high: '#222a3d'
  surface-container-highest: '#2d3449'
  on-surface: '#dae2fd'
  on-surface-variant: '#bbcabf'
  inverse-surface: '#dae2fd'
  inverse-on-surface: '#283044'
  outline: '#86948a'
  outline-variant: '#3c4a42'
  surface-tint: '#4edea3'
  primary: '#4edea3'
  on-primary: '#003824'
  primary-container: '#10b981'
  on-primary-container: '#00422b'
  inverse-primary: '#006c49'
  secondary: '#ffb3ad'
  on-secondary: '#68000a'
  secondary-container: '#a40217'
  on-secondary-container: '#ffaea8'
  tertiary: '#ffb3af'
  on-tertiary: '#650911'
  tertiary-container: '#fc7c78'
  on-tertiary-container: '#711419'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#6ffbbe'
  primary-fixed-dim: '#4edea3'
  on-primary-fixed: '#002113'
  on-primary-fixed-variant: '#005236'
  secondary-fixed: '#ffdad7'
  secondary-fixed-dim: '#ffb3ad'
  on-secondary-fixed: '#410004'
  on-secondary-fixed-variant: '#930013'
  tertiary-fixed: '#ffdad7'
  tertiary-fixed-dim: '#ffb3af'
  on-tertiary-fixed: '#410005'
  on-tertiary-fixed-variant: '#842225'
  background: '#0b1326'
  on-background: '#dae2fd'
  surface-variant: '#2d3449'
typography:
  display-timer:
    fontFamily: Inter
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 48px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '500'
    lineHeight: 28px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-caps:
    fontFamily: JetBrains Mono
    fontSize: 14px
    fontWeight: '700'
    lineHeight: 20px
    letterSpacing: 0.05em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  unit: 8px
  gutter: 16px
  margin-page: 24px
  card-padding: 20px
  touch-target-min: 48px
---

## Brand & Style

This design system is engineered for the high-intensity environment of professional kitchens. The brand personality is efficient, reliable, and authoritative, designed to reduce cognitive load for chefs and line cooks. 

The aesthetic leverages **Corporate Modern** principles with a utilitarian edge. It focuses on extreme legibility and functional hierarchy to ensure that critical information—like order timers and modification alerts—is processed instantly. The interface remains unobtrusive with a deep slate foundation, allowing high-vibrancy status colors to command attention only when necessary.

## Colors

The palette is optimized for low-light, high-heat kitchen environments to prevent eye strain while maintaining critical contrast ratios.

- **Background (#0F172A):** The base layer for the application, providing a deep, non-reflective canvas.
- **Primary / Active (#10B981):** Used exclusively for "Active," "Cooking," or "Complete" states. This vibrant green signals forward momentum.
- **Secondary / Alert (#EF4444):** Reserved for "Priority," "Overdue," or "Voided" items. It is the highest priority color in the visual field.
- **Surface (#1E293B):** Used for order cards and containers to create a subtle lift from the background.
- **Neutral/Text:** High-contrast whites and grays ensure secondary details (like order notes) remain readable under harsh kitchen lighting.

## Typography

This design system utilizes **Inter** for its exceptional legibility and neutral tone. To assist with technical data like order IDs and timestamps, **JetBrains Mono** is introduced for labels to provide a distinct "data-driven" feel.

- **Scale:** Font sizes are intentionally larger than standard SaaS applications to account for distance viewing (chefs often view screens from 3-5 feet away).
- **Emphasis:** Use Bold (700) for item names and Medium (500) for modifications. 
- **Modifications:** Special instructions or "No [Ingredient]" should always be rendered in a slightly larger, high-contrast weight to prevent errors.

## Layout & Spacing

The layout uses a **Fluid Grid** system optimized for large-format touchscreens and tablets. 

- **Grid:** Orders are arranged in a multi-column flow. On desktop/large KDS monitors, use a 4 or 5 column layout. On tablets, move to a 2 column layout.
- **Touch Targets:** All interactive elements (bump buttons, status toggles) must adhere to a minimum 48px touch target to accommodate gloved hands or rapid interactions.
- **Rhythm:** An 8px linear scale governs all spacing. Order cards use 16px gutters to ensure clear separation of distinct tickets.

## Elevation & Depth

To maintain a clean and fast-rendering UI, this design system uses **Tonal Layers** combined with **Ambient Shadows**.

- **Level 0 (Background):** #0F172A. Used for the global navigation and empty states.
- **Level 1 (Card Base):** #1E293B. Used for standard order cards. Includes a subtle 1px border (#334155) to define edges.
- **Level 2 (Active/Selected):** A soft, diffused outer glow using the primary green (#10B981) at 20% opacity.
- **Shadows:** Use large, soft blurs (Y: 4, Blur: 20) with 40% opacity black to separate cards from the background without creating visual clutter.

## Shapes

The shape language is **Soft**, utilizing a 0.25rem (4px) base radius. This creates a professional, organized look that feels "contained" and sturdy.

- **Standard Elements:** 4px radius for input fields and small chips.
- **Order Cards:** 8px (rounded-lg) to soften the large surface area.
- **Action Buttons:** 4px radius to maintain a sense of "physical" machinery buttons.

## Components

### Order Cards
The central component of the system. Cards must have a clear header containing the Order ID and a prominent Timer. 
- **Header:** Background shifts to #EF4444 if the order is late.
- **Content:** Bulleted list of items. Bold for main items, indented for modifications.

### Interactive Buttons (Bump Buttons)
Large, full-width buttons at the bottom of cards.
- **Primary Action:** Solid #10B981 background with white text.
- **Secondary Action:** Ghost style with 2px borders.

### Status Chips
Small, high-contrast badges used for order types (e.g., "Dine In", "Takeaway").
- **Dine In:** Outline white.
- **Takeaway/Delivery:** Solid #334155 with white text.

### Timers
Located in the top right of every card.
- **Normal:** Text #94A3B8.
- **Warning (approaching limit):** Text #F59E0B (Amber).
- **Critical (late):** Text #EF4444.

### Global Navigation
A slim left or top rail in #0F172A. Icons should be line-art style with a 2px stroke width for maximum clarity.