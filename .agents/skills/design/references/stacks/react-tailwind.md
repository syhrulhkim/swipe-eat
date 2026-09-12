# Stack: React + Tailwind

Use when the project is React (Vite, CRA, or an artifact) and Tailwind is present or requested.

## Tokens
- Put brand tokens in `tailwind.config` under `theme.extend` (colors, fontFamily, borderRadius, boxShadow). In an artifact environment without a config, define CSS variables in a top-level `<style>` or global CSS and reference them with arbitrary values: `bg-[var(--color-primary)]`. Never hardcode hex in `className`.
- Name colors by role (`primary`, `surface`, `muted`) not by hue, so a rebrand is a config change.

## Components
- Functional components, one per file, default export. Props have defaults; no required props for demo renders.
- Sections are components: `Hero`, `Proof`, `Features`, `FinalCta`. Page composes them. Copy is passed as props or lives in a `content` object at the top so it's editable in one place.
- Extract repeated Tailwind class strings into a small component or a `cn()` helper rather than copy-pasting.
- Only core Tailwind utility classes — no plugin-only classes unless the plugin is confirmed installed.

## Motion
- Prefer CSS transitions via Tailwind (`transition`, `duration-*`) for user-triggered motion. For the one orchestrated page-load moment, a small `useEffect` toggling a class is enough; don't pull in an animation library unless asked.
- Honor `motion-reduce:` variants.

## Accessibility floor
- `focus-visible:ring-*` on all interactive elements.
- Icons from lucide-react get `aria-hidden` when decorative; interactive icon buttons get `aria-label`.
- Semantic elements over `div` soup; Tailwind doesn't change that.
