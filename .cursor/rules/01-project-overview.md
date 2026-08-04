---
description: Project overview, tech stack, and golden rules for the La Botica KDS Flutter app. Always relevant background context for any task in this repo.
alwaysApply: true
---

# Project Overview — Order master Kitchen Display System (KDS)

## What we're building
A Flutter tablet/desktop app that shows live kitchen orders as a **masonry-style
grid of dynamic-height cards**. No scrolling — if an order overflows its column,
it continues in a linked card in the next column ("Continued...").

## Tech stack
- Flutter (stable channel, latest)
- State management: **Riverpod** (use `hooks_riverpod` only if hooks are already
  in the project; otherwise plain `flutter_riverpod` — don't add hooks just because
  it's trendy)
- Architecture: **MVC**, kept simple (see `02-architecture.md`)
- Target platforms: tablet/desktop landscape, real-time kitchen environment

## Golden rules for this project
1. **Simple over clever.** This is a kitchen screen, not a framework showcase.
   If a plain `StatelessWidget` + a couple of providers solve it, don't reach for
   extra layers "for future flexibility."
2. **No premature abstraction.** Don't create repository interfaces, use-case
   classes, or DI containers for things we only do one way. Add abstraction only
   when there's a second real implementation to swap in.
3. **Every screen must run at 60fps** on the target tablet. Kitchen staff glance
   at this screen constantly — jank is a real complaint, not a nitpick.
4. **Prefer boring, well-known Flutter patterns** over novel ones. A future dev
   (or Cursor, six months from now) should understand the code without reading
   this file.
5. When Cursor is unsure between a simple and a "proper enterprise" solution for
   this codebase, **it should pick simple** and leave a short comment explaining
   why, rather than silently picking the heavier option.
