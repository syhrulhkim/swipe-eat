# Stack: Next.js (App Router)

Use when the project is Next.js or the user says "Next", "app router", "Vercel".

## Structure
- `app/page.tsx` composes section components from `components/sections/`. Shared UI (buttons, containers) in `components/ui/`.
- Site-wide tokens in `app/globals.css` as CSS variables on `:root`, mapped into `tailwind.config` if Tailwind is used. Fonts via `next/font` (Google or local) so they self-host and avoid layout shift; expose them as CSS variables and reference those in tokens.
- Copy in `content/` (TS objects or MDX) so marketing can edit without touching components.

## Conventions
- Server components by default; add `"use client"` only where there's interactivity or browser APIs.
- `next/image` for all images with explicit `width`/`height` or `fill` + `sizes`. Placeholder assets go in `public/placeholders/` with descriptive names.
- Metadata via the `metadata` export: title, description, OpenGraph. A landing page without OG tags is unfinished.
- Links via `next/link`; external links get `rel="noopener"`.

## Motion and accessibility
- Same rules as react-tailwind.md. Keep animation client components small and leaf-level so the rest of the page stays server-rendered.
