---
description: General Dart/Flutter coding conventions, commenting style, and dependency-introduction guardrails for Cursor. Always relevant for any code change in this repo.
alwaysApply: true
---

# General Cursor Coding Conventions

These apply to any code Cursor generates or edits in this repo.

## Before writing code
- Check existing files in `models/`, `controllers/`, `services/` before creating
  a new one — reuse/extend existing classes rather than duplicating similar
  logic under a new name.
- If a change touches layout/performance-sensitive areas (the order grid),
  re-read `04-performance-and-layout.md` first.

## Code style
- Follow standard Dart/Flutter lint rules (`flutter_lints`). Don't disable lints
  to make code compile faster — fix the actual issue.
- Prefer small, single-purpose functions/widgets over long `build()` methods.
  If a `build()` method exceeds ~50–60 lines, extract private widgets/methods.
- Use explicit types for public APIs (controller methods, model fields); `var`
  is fine for obvious local inference.
- Null-safety: avoid `!` (force unwrap) unless truly guaranteed non-null right
  above it; prefer `if (x != null)` narrowing or `??`.

## Comments
- Comment the *why*, not the *what* — e.g. explain why the masonry packing is
  done in a provider instead of in the widget tree, not what a for-loop does.
- Leave a short comment wherever a "simple vs proper" tradeoff was made
  intentionally (see `01-project-overview.md` golden rule #5), so a future dev
  understands it was a deliberate choice.

## What NOT to introduce without being asked
- No new state management library alongside Riverpod.
- No code generation tooling (freezed, json_serializable, riverpod_generator)
  unless it's already in `pubspec.yaml` — ask/flag it instead of silently
  adding a new dependency and build step.
- No custom routing package unless navigation gets non-trivial (this app is
  likely 2–3 screens: Kitchen Display, Completed Orders, maybe Settings) —
  Navigator 2.0/go_router only if the project already needs deep-linking.
- No test framework changes — use `flutter_test` + `mocktail` (or whatever's
  already set up) for controller/logic tests; widget tests only for the
  packing algorithm and status-transition logic, not for pixel-perfect UI.

## When making changes
- Prefer editing/extending an existing widget or controller over creating a
  parallel "v2" version.
- Run `flutter analyze` (mentally or literally) before considering a task
  done — no unused imports, no dead code left behind from refactors.
- Keep commits/diffs focused on the requested feature — don't opportunistically
  restyle or restructure unrelated code in the same change.
