---
name: design
description: Studio workflow for designing and building web UI — landing pages, marketing sites, product screens, and app interfaces — for multiple clients on whatever stack the project uses (plain HTML/CSS, React + Tailwind, Next.js). Extends the built-in frontend-design skill with a brief-intake step, per-client brand references, stack conventions, and a landing-page conversion checklist. Use this whenever the user invokes /design, or asks to design, build, mock up, redesign, or restyle any web page, landing page, hero, section, component, or UI — even if they just say "make me a page for X" or paste a brief. Also use it when the user mentions a client name alongside anything visual, or asks for a design system, tokens, or brand styling for a site.
---

# Design (studio workflow)

This skill sits on top of the built-in `frontend-design` skill. That skill owns the craft: aesthetic direction, typography, anti-default calibration, motion restraint, copywriting, and the plan → review → build → critique loop. This skill adds what a working studio needs around that craft: knowing which client this is for, which stack it ships on, and what a landing page must actually do.

**Step 0 — always load the craft skill first.** Read `/mnt/skills/public/frontend-design/SKILL.md` before anything else in this skill. Everything below assumes its guidance is in context. If it can't be found, proceed with this file alone but note that to the user.

## Step 1 — Intake the brief

A brief is rarely complete. Before planning, extract or decide these five things, and state them back to the user in a short block so they can correct you before you spend effort:

| Field | How to determine it |
|---|---|
| **Client / brand** | Named in the brief? Check `references/clients/` for a matching file. If none exists, ask whether this is a new client worth saving, or a one-off. |
| **Page type** | Landing page, multi-section marketing site, product/dashboard UI, portfolio, single component. Default for this studio is landing page. |
| **Primary job** | The one thing the page must make a visitor do or understand. A landing page has exactly one conversion goal; if the brief lists several, pick the primary and demote the rest. |
| **Audience** | Who arrives here and what they already believe. This drives tone more than the brand does. |
| **Stack** | Named in the brief, or inferable from the project (existing files, package.json, mention of a framework). If nothing indicates, default to a single self-contained HTML file — it's the fastest thing to review. |

Then load only what's needed:
- `references/clients/<client>.md` if a client file exists. Its tokens and voice **override** any aesthetic choice you would otherwise make.
- `references/stacks/<stack>.md` for the chosen stack's conventions.
- `references/landing-page.md` when the page type is a landing page or marketing site.

If the brief is genuinely too thin to pin down subject, audience, and job, propose all three as a single concrete guess and ask for a yes/no rather than open-ended questions. Waiting for a perfect brief wastes more time than one round of correction.

## Step 2 — Plan, exactly as frontend-design describes

Produce the compact token system (color, type, layout with ASCII wireframe, principles) and run the review-against-the-brief pass. Two studio-specific additions:

- **When a client file exists**, the plan does not invent a palette or typefaces; it applies the client's and spends its creativity on layout, hierarchy, imagery direction, and the one signature element. Say explicitly which choices came from the client file and which are yours.
- **When there is no client file**, the plan is also a proposal for one. Format the color and type sections so they could be pasted into a new `references/clients/<name>.md` with minimal editing. Offer to save it at the end.

## Step 3 — Build on the chosen stack

Follow the stack reference. Regardless of stack, the studio floor is:

- Every color, font, radius, and spacing step is a named token in one place. No hex values scattered through markup or component files. A client rebrand should be a token-file change.
- Responsive to 360px wide without horizontal scroll. Check the hero and any multi-column section at 360, 768, and 1280.
- Visible keyboard focus on every interactive element; `prefers-reduced-motion` respected; text contrast meets WCAG AA against its actual background, including over images.
- Real copy, not lorem ipsum. If the brief has no copy, write plausible copy for this subject and mark it clearly as placeholder in a comment, not in the visible text.
- Images: use a neutral placeholder treatment (solid tone, subtle gradient, or CSS shape) with a descriptive `alt` and a comment stating what the real asset should be. Never hotlink random stock photos.

## Step 4 — Critique, then hand off

Do the frontend-design self-critique. Then add a short **handoff note** at the end of the response — a few lines, not a report:

1. The one aesthetic risk you took and why it fits this brief.
2. Anything you assumed that the user should confirm (audience, copy, missing brand detail).
3. What's placeholder and needs real assets.
4. If no client file existed: the offer to save the tokens as `references/clients/<name>.md`.

Keep the handoff conversational. Don't restate what the page contains — they can see it.

## Multiple clients: keeping them apart

The main failure mode of a multi-client studio is drift: client B's page starts to look like client A's because the same designer made both last week. Guard against it deliberately:

- Never reuse a palette, typeface pairing, or signature element across clients unless both client files specify it.
- When two clients are in the same industry, push them further apart, not closer; the brief's subject matter should generate the differences (see frontend-design on grounding in subject matter).
- If you've designed for this client before in the current session, reuse their tokens exactly but don't repeat the layout concept.

## Adding a client

To add or update a client, copy `references/clients/_template.md` to `references/clients/<client-slug>.md` and fill it in. Keep each file under ~80 lines: tokens, type, voice, and a short do/don't list learned from past feedback. The do/don't list is the most valuable part — add to it whenever a client rejects something.
