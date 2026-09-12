// Serves the three public web pages the stores ask for by URL:
//
//   /functions/v1/legal/privacy         — privacy policy (required by both stores)
//   /functions/v1/legal/delete-account  — account & data deletion instructions,
//                                         which Google Play requires as a *web*
//                                         URL reachable without installing the
//                                         app or signing in
//   /functions/v1/legal/terms           — terms of use
//
// Auth: verify_jwt is off (see supabase/config.toml) because these pages must
// open in any browser with no key. They are static text and read nothing from
// the database, so there is nothing here to protect.
//
// The wording is a plain-language description of what the app actually does. It
// has not been reviewed by a lawyer; see docs/Release/STORE.md.
const CONTACT_EMAIL = Deno.env.get("LEGAL_CONTACT_EMAIL") ??
  "support@swipeeat.app";
const LAST_UPDATED = "11 September 2026";

function page(title: string, body: string): Response {
  const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title} — Swipe Eat</title>
<style>
  :root { color-scheme: light dark; }
  body {
    margin: 0 auto; padding: 2.5rem 1.25rem 4rem; max-width: 42rem;
    font: 16px/1.65 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    background: #ffffff; color: #16150f;
  }
  h1 { font-size: 1.75rem; line-height: 1.2; margin: 0 0 0.25rem; }
  h2 { font-size: 1.1rem; margin: 2rem 0 0.5rem; }
  p, li { margin: 0.6rem 0; }
  ul, ol { padding-left: 1.25rem; }
  .updated { color: #6b6a60; font-size: 0.875rem; margin: 0 0 1.5rem; }
  a { color: #16150f; }
  nav { margin-top: 3rem; font-size: 0.875rem; }
  @media (prefers-color-scheme: dark) {
    body { background: #16150f; color: #f4f1e6; }
    .updated { color: #a5a294; }
    a { color: #f4f1e6; }
  }
</style>
</head>
<body>
<h1>${title}</h1>
<p class="updated">Swipe Eat · last updated ${LAST_UPDATED}</p>
${body}
<nav>
  <a href="./privacy">Privacy</a> ·
  <a href="./delete-account">Delete your account</a> ·
  <a href="./terms">Terms</a>
</nav>
</body>
</html>`;
  return new Response(html, {
    status: 200,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "public, max-age=3600",
    },
  });
}

const PRIVACY = `
<p>Swipe Eat helps you find places to eat by swiping through restaurants near
you. This page explains exactly what the app stores and why.</p>

<h2>What we collect</h2>
<ul>
  <li><strong>Your email address and name</strong> — to create and identify your
  account. If you sign in with Google or Apple, we receive these from that
  provider instead of asking you for a password.</li>
  <li><strong>Your approximate location</strong> — used on the device and sent to
  our server to rank restaurants by distance and to draw the map. The most recent
  fix is stored on your profile so the app still knows roughly where you are when
  you open it with location turned off. We do not keep a history of where you
  have been.</li>
  <li><strong>Your taste choices</strong> — the cuisines and dietary tags you
  pick, whether you want halal-only or vegetarian places, how much spice and how
  much money you are up for, your search radius, and your answers to the taste
  quiz.</li>
  <li><strong>What you do with restaurants</strong> — which you liked, passed on,
  saved to your wishlist or marked as visited. We also store, for a swipe made on
  the main screen, how long the card was in front of you and whether its video
  had the sound on, because how sure you were is part of what you told us. This
  is what makes the recommendations yours.</li>
  <li><strong>Your plans</strong> — the restaurant, the day and the time you
  picked, who you invited, and how the people you invited voted on the time. A
  plan is private to you and the people on it unless you turn on <em>Share with
  friends</em> for that one plan, which is off until you do: then the friends
  you have on Swipe Eat can see that plan on their calendar and ask to join it,
  and you decide who gets in. We also store who has asked.</li>
  <li><strong>Your friends</strong> — who you are friends with on Swipe Eat, and
  friend requests in either direction.</li>
  <li><strong>Contacts, when you ask us to look</strong> — if you tap "Find
  friends", the app reads your address book <em>on the phone</em> and scrambles
  each phone number into a one-way code. <strong>Only those codes are sent</strong>,
  they are compared against the accounts we know, and they are thrown away with
  the answer. No name, no number and no address book entry ever leaves your
  phone, and nothing from your address book is stored on our server. If you
  verify a phone number on your own account, we store a scrambled code for
  <em>that</em> number so people who already have it can find you.</li>
  <li><strong>Your reviews</strong> — if you rate a place you went, we store your
  stars and the line you wrote. <strong>Your friends on Swipe Eat can read
  them</strong>, under your name; nobody else can. Your stars also count towards
  the average rating shown on that restaurant, which everyone sees — a number,
  never your name.</li>
  <li><strong>A notification code for your phone</strong> — so we can tell you
  when somebody invites you to a plan, asks to join one of yours, or lets you
  in. It identifies the app on this device, not you personally, and it is
  deleted when you sign out or delete your account. If you say no to
  notifications, there is nothing to store.</li>
  <li><strong>Crash and error reports</strong> — if the app crashes we send
  diagnostic data (device model, OS version, stack trace) to Sentry so we can fix
  it.</li>
</ul>

<h2>What we do not do</h2>
<ul>
  <li>We do not sell your personal data.</li>
  <li>We do not track you across other companies' apps or websites, and we do not
  use your data for third-party advertising.</li>
  <li>We do not upload your address book. See "Contacts" above: what is sent is a
  one-way scramble of the numbers, and it is not kept.</li>
  <li>We do not ask for your photos, your microphone, or your location while the
  app is closed.</li>
</ul>

<h2>Who processes your data</h2>
<p>Your account and preferences are stored with
<a href="https://supabase.com/privacy">Supabase</a>, our database and
authentication provider. Crash reports go to
<a href="https://sentry.io/privacy/">Sentry</a>. Restaurant videos are embedded
from TikTok and are subject to TikTok's own privacy policy when they play.
Sign-in with Google or Apple is handled by those companies.</p>

<h2>How long we keep it</h2>
<p>We keep your account data until you delete your account. Deleting your account
removes all of it — your profile, your preferences, your swipes, your wishlist,
your plans, your friendships and your reviews — immediately and permanently. See
<a href="./delete-account">Delete your account</a>.</p>

<h2>Your rights</h2>
<p>You can see and change your details in the app, and you can delete your
account and all its data at any time. To ask a question or request a copy of your
data, email <a href="mailto:${CONTACT_EMAIL}">${CONTACT_EMAIL}</a>.</p>

<h2>Children</h2>
<p>Swipe Eat is not directed at children under 13 and we do not knowingly collect
their data.</p>

<h2>Changes</h2>
<p>If this policy changes we will update this page and the date at the top.</p>
`;

const DELETE_ACCOUNT = `
<p>You can delete your Swipe Eat account and all of its data yourself, from
inside the app. No email or waiting period is involved.</p>

<h2>Delete it from the app</h2>
<ol>
  <li>Open Swipe Eat and sign in.</li>
  <li>On the swipe screen, tap the gear icon in the top right to open
  <strong>Settings</strong>.</li>
  <li>Scroll to <strong>Account</strong> and tap <strong>Delete account</strong>.</li>
  <li>Confirm. Your account is deleted straight away and you are signed out.</li>
</ol>

<h2>If you cannot open the app</h2>
<p>Email <a href="mailto:${CONTACT_EMAIL}">${CONTACT_EMAIL}</a> from the address
you signed up with and ask us to delete your account. We will confirm it is you,
delete the account, and reply within 30 days.</p>

<h2>What gets deleted</h2>
<ul>
  <li>Your account and sign-in credentials.</li>
  <li>Your name, email address and profile.</li>
  <li>Your saved location and search radius.</li>
  <li>Your cuisine and dietary preferences, and your quiz answers.</li>
  <li>Every restaurant you liked, saved, passed on or marked as visited.</li>
  <li>Your plans and the invitations and time votes attached to them.</li>
  <li>Your friendships, and any friend requests waiting either way.</li>
  <li>Your reviews — the stars and the line you wrote. The restaurant's average
  is recalculated without them.</li>
  <li>The scrambled code for your own verified phone number, if you have one.</li>
</ul>
<p>All of the above is deleted immediately and permanently — it cannot be
restored, and you would start from scratch if you signed up again.</p>

<h2>What is kept</h2>
<ul>
  <li>Our restaurant catalogue, which is not personal data.</li>
  <li>Crash reports already sent to Sentry, which are deleted on Sentry's own
  90-day retention schedule.</li>
</ul>
`;

const TERMS = `
<h2>Using Swipe Eat</h2>
<p>Swipe Eat suggests restaurants. You need an account to use it, and you are
responsible for keeping your sign-in details to yourself. Do not use the app to
break the law or to interfere with the service.</p>

<h2>Restaurant information</h2>
<p>Restaurant names, addresses, opening details and videos come from public
sources including TikTok posts by food creators and open map data. We check what
we can, but details change and mistakes happen: confirm with the restaurant
before you travel. Swipe Eat does not run any restaurant and does not take
bookings or payments.</p>

<h2>What you write</h2>
<p>If you rate a place, the stars and the line you write are shown to your
friends on Swipe Eat under your name, and your stars count towards that
restaurant's average rating. Write about the meal, not about people; do not post
anything unlawful, abusive or untrue. We may remove a review, and you can remove
yours by rating the place again or by deleting your account.</p>

<h2>Content from third parties</h2>
<p>Videos are embedded from TikTok and belong to the people who posted them.
Playing one is also subject to TikTok's terms.</p>

<h2>Availability</h2>
<p>The service is provided as-is. We may change or stop features, and we are not
liable for indirect loss arising from using the app.</p>

<h2>Ending your use</h2>
<p>You can delete your account at any time — see
<a href="./delete-account">Delete your account</a>. We may suspend accounts that
abuse the service.</p>

<h2>Contact</h2>
<p>Questions: <a href="mailto:${CONTACT_EMAIL}">${CONTACT_EMAIL}</a>.</p>
`;

const INDEX = `
<p>Legal and data pages for the Swipe Eat mobile app.</p>
<ul>
  <li><a href="./legal/privacy">Privacy policy</a></li>
  <li><a href="./legal/delete-account">Delete your account and data</a></li>
  <li><a href="./legal/terms">Terms of use</a></li>
</ul>
`;

Deno.serve((req) => {
  // Match on the last path segment so the function works whether it is reached
  // at /functions/v1/legal/privacy or behind a custom domain rewrite.
  const segment = new URL(req.url).pathname.replace(/\/+$/, "").split("/")
    .pop() ?? "";

  switch (segment) {
    case "privacy":
    case "privacy-policy":
      return page("Privacy policy", PRIVACY);
    case "delete-account":
    case "data-deletion":
      return page("Delete your account", DELETE_ACCOUNT);
    case "terms":
      return page("Terms of use", TERMS);
    default:
      return page("Swipe Eat", INDEX);
  }
});
