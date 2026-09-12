# Stack: plain HTML / CSS / JS

Default when nothing in the brief indicates a framework. Fastest to review, no build step.

## File layout
- One self-contained `index.html` with a `<style>` block and, if needed, a `<script>` block at the end of `<body>`. Split into `styles.css` / `main.js` only if the user asks or the page exceeds ~600 lines.
- Tokens live in `:root { }` at the top of the stylesheet, grouped: colors, type, spacing, radius, shadow, motion. Nothing else in the file uses a raw hex or px value that a token could express.

## Conventions
- Semantic landmarks: `header`, `main`, `section` with an `aria-labelledby` heading, `footer`. One `h1`.
- Class names describe role, not appearance: `.hero`, `.proof`, `.cta-primary` — not `.blue-box`, `.mt-40`.
- Layout with CSS grid / flex and `clamp()` for fluid type and spacing. Avoid fixed heights on text containers.
- Fonts via a single Google Fonts `<link>` with `display=swap`, or `@font-face` if self-hosted. Provide a system fallback in the stack.
- Motion: define `--motion-duration` and `--motion-ease` tokens; wrap non-essential motion in `@media (prefers-reduced-motion: no-preference)`.
- Watch selector specificity for section spacing (frontend-design calls this out). Prefer a single `.section` padding rule plus modifier classes over per-section overrides.

## Accessibility floor
- `:focus-visible` styles on links, buttons, inputs.
- Skip link to `#main`.
- Every image has `alt`; decorative ones use `alt=""`.
- Buttons are `<button>` or `<a href>`, never clickable `div`s.
