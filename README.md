# sese-wedding

Jacopo & Agnese’s wedding website, built with Vue 3, TypeScript, Vite and Tailwind CSS.

Use Node.js 22.22.2+ or 24.15+. Run `npm install` and `npm run dev` to develop; `npm run build` to type-check and build for production.

Edit `src/content/wedding.ts` for names, date, location, schedule, travel and accommodation. Empty fields display placeholder copy. Map links appear when `mapsUrl` is set. RSVP responses can be saved in Supabase as described below.

The layout is in `src/App.vue`. Tailwind theme tokens and minimal global styles are in `src/assets/main.css`. The FAQ titles use the locally hosted Cinzel font; its license is included in `public/fonts`. Supabase is optional for local preview and required to save RSVP responses.

The cinema programme uses `events` in `src/content/wedding.ts`. Event stages are illustrative; update them to match the actual schedule.

## RSVP and personal invitation links

The RSVP form is public. Guests enter any number of named people (up to 100 per group), with attendance for each. Submitting creates the family, guests and responses in the dashboard, using the first person's name as the group label. Personal links remain optional: they load an existing family and allow additional named members to be saved to that family. Responses can be edited on the same page after saving.

Apply `20261109000006_public_rsvp.sql` before deploying this frontend. The new public registration RPC validates input and saves the whole group atomically.

Each family has exactly one invitation link, including families with just one person. Named families see their family name, the list of guests (for example “Famiglia Murelli: Chiara e Francesco +1”), and attendance choices for each person. Headcount families see their family name and **Confermiamo per:** with a number input. Anyone with the link can view and update that family’s response, so share it privately. The cinema seat and barcode on the guest ticket remain illustrative and separate from the admin seating plan.

### Set up Supabase

1. Create a Supabase project. In its SQL editor, run all SQL migrations in `supabase/migrations/` in filename order, once each. These create families, guests, invitations, responses and token-scoped functions. The table has row level security enabled and no public table access; the functions validate inputs; public registration creates a new group, while updates require its token.
2. Copy `.env.example` to `.env.local`, then set `VITE_SUPABASE_URL` to the project URL and `VITE_SUPABASE_PUBLISHABLE_KEY` to the project publishable key (a legacy anon key also works). These are public browser settings. Never use a secret or service role key here.
3. Restart the development server. The RSVP form is always available. Valid personal links prefill the existing family; missing or invalid tokens show the public registration form. Supabase settings are required to save responses.
4. For GitHub Pages, add the same two values as repository variables under **Settings → Secrets and variables → Actions → Variables**, then redeploy. Vite embeds them at build time. Until both variables are configured, the deployed form cannot save responses.

### Manage guests and responses

Open `/sese-wedding/dashboard/` on the deployed site (or `/sese-wedding/dashboard/` on the local Vite server). The dashboard has no link from the guest site. Its initial password is `admin`, as requested for setup. **Change it immediately using the dashboard before adding real guests or sharing the site:** this initial password is public and allows anyone to see and edit invitation data. The password is checked by the database on each request and stored there as a bcrypt hash. This simple shared-password design has no account management or rate limiting; use Supabase Auth and proper authorization before relying on it for sensitive information.

Use **Crea una famiglia** to enter the family name and choose how it responds:

- **Per ciascun membro nominativo**: enter one name per line, including a single name for an individual guest. The ticket lists those names and collects attendance per member. You can add another member later without changing the family link.
- **Con il numero di persone**: enter a private maximum (1–100). Guests enter a whole number of attendees, including 0 to decline. The initial capacity grows when a public RSVP confirms more people, creating additional guest slots for seating. The capacity is omitted from the guest API response, input attributes, labels, and validation messages. It is visible only in the authenticated admin list. The chosen count is saved and can be edited using the same link.

Each family has the independent boolean **Consenti +1**, disabled by default. The companion field appears only when enabled and someone is attending. For headcount families, a permitted +1 is additional to the private maximum. Disabling the flag removes the saved companion and frees their seat. The attendance total counts the companion once.

Apply all migrations in filename order. `20261109000005_family_invitations.sql` consolidates existing invitation rows to one per family, retaining the oldest active link where possible and invalidating the other old member links. Copy the canonical family link from the updated admin list. Member responses and existing seat assignments are preserved.

`public.invitations.family_id` is unique. `public.responses` stores one response per `guest_id`; `public.family_responses` stores shared notes, the response date, and the confirmed headcount. Headcount families have numbered guest placeholders for seating: confirmed slots are green, unused slots become absent/red after an answer, and unanswered slots are amber. Guests never receive these placeholders or their count in the invitation payload.

To revoke a family link, set its invitation’s `revoked_at` to `now()`. To replace it, set `token` to `gen_random_uuid()` and clear `revoked_at`. Family membership, answers, and seating remain associated with the family.

The token is an access credential: anyone with the link can view and edit the associated response. Share it privately. The site uses a no-referrer policy to avoid passing it to linked sites. An invitation link does not prove the recipient's identity.

`?invite=<token>#presenza` optionally loads an existing family and its saved response. Guests can also register without a token. Names are limited to 160 characters and notes to 1,000 characters. Failed saves leave the form available for retry; successful saves play the ticket animation.

Edit `src/content/faqs.json` to add, remove or reorder FAQs. Each entry has a unique `id` (also used for its anchor), a plain-text `question`, an optional plain-text `subtitle` (omit it or leave it empty to hide it), and an `answerHtml` string. Answers render as HTML, so you can add paragraphs, links, lists and Tailwind classes. Keep this HTML authored in the repository; it is rendered directly without sanitization. Escape double quotes inside JSON strings, for example:

```json
{
  "id": "faq-parcheggio",
  "question": "Dove posso parcheggiare?",
  "answerHtml": "<p>Il parcheggio è <strong>gratuito</strong>.</p><p class=\"mt-4 text-olive\">Segui le indicazioni all’ingresso.</p>"
}
```

FAQ listings and spacing can be adjusted in `src/App.vue` and the cinema board styles in `src/assets/main.css`. Changes to the JSON are included on the next build.

## Local network preview

Run `npm run dev` and open `http://<your-PC-IP>:5173/sese-wedding/` from a device on the same network. For the production preview, run `npm run build` then `npm run preview` and use port `4173` instead. Both servers listen on all IPv4 interfaces and use fixed ports; a busy port is reported instead of silently changing the URL.

If Windows Firewall blocks access, run `powershell -ExecutionPolicy RemoteSigned -File .\scripts\Enable-LocalNetwork.ps1` from an administrator terminal. This allows TCP ports 5173 and 4173 from the local subnet. The firewall stays enabled. To remove the allow rule, run `Remove-NetFirewallRule -Name SeseWedding-LocalNetwork` as administrator.

## GitHub Pages deployment

The site deploys to https://ubriacopo.github.io/sese-wedding/ through `.github/workflows/deploy.yml`. In the GitHub repository, select **Settings → Pages → Build and deployment → Source → GitHub Actions** once. Every push to `master` then installs dependencies, checks types, builds the site and deploys `dist/`. You can also run the workflow manually from the Actions tab.

Vite's `base` is `/sese-wedding/` to match the repository path. Update it if the repository name changes; use `/` when moving to a custom domain. Commit `package-lock.json` and `env.d.ts` so the deployment can install and type-check the project. Keep `dist/` and `node_modules/` out of Git.

## Upcoming movie slideshow

Configure all films in the single array `src/content/movies.json`. Array order is slideshow order: add, remove or reorder entries directly in that file.

Place posters in `public/posters/` and refer to the filename in `poster`:

```json
[
  {
    "title": "Il nostro film",
    "poster": "noi.jpg",
    "tagline": "La nostra storia, sul grande schermo.",
    "genre": "Commedia romantica"
  }
]
```

`tagline`, `genre`, `release`, `fallbackPoster` and `id` are optional. IDs are generated if omitted; use unique IDs if setting them manually. The illustrated fallback can be `ceremony`, `toast`, `dinner` or `party`; it is shown if `poster` is empty or fails to load. A full HTTPS image URL also works. Portrait posters (ideally 2:3) work best. Local images resolve under the GitHub Pages base path automatically.

The compact slideshow shows the poster, genre, title and tagline. It supports arrows, numbered selectors and left/right keyboard keys, and advances manually. An empty array hides the section and navigation link; a single film hides the controls.

## Gift configuration

Configure `gift` in `src/content/wedding.ts` for the cinema end-credits gift section. Add both `iban` and `accountHolder` to display bank details and the copy button; otherwise the placeholder is shown. `reference` is optional. The copy button selects the IBAN for manual copying if clipboard access is unavailable (including some LAN HTTP connections).

The FAQ board uses `showtime` (for example `15:30`) and `seatsLeft` (for example `42`) in each FAQ entry as cinema decorations. These values do not represent the wedding schedule or actual remaining capacity.

## Invitation regression checks

Run `npm run build` for Vue and TypeScript validation. For database behavior, run `supabase/tests/family_plus_one.sql` as the database owner in the Supabase SQL editor after applying migrations. This standalone SQL check raises an exception on failure and rolls back its temporary guests, responses, and dashboard password setting. It checks one link per family, named and headcount answers, hidden and enforced capacity, unrelated-member rejection, companion permissions, response updates, authorization, and revoked links. No test framework is required.

## Seating plan

After signing in to the dashboard, open the second tab, **Tavoli e posti**, to create and rename tables, choose a capacity of 1–20 numbered seats, and drag tables around the room. Positions, table settings, and assignments are stored in Supabase. Use the arrow buttons as an alternative to dragging, and zoom or scroll the plan on smaller screens.

Select a guest from the searchable roster (or an occupied seat), choose a table and seat, and press **Assegna posto**. You can also select a free seat in the drawing to fill the destination fields. Moving a person frees their previous seat. Occupied seats cannot be overwritten, and reducing a table’s capacity requires first moving anyone sitting in the seats being removed. Unassign a person with **Rimuovi assegnazione**.

Green means confirmed, amber means awaiting a response, and red means absent. Labels and the filter identify these statuses without relying on color. Pending and absent guests may still be seated while planning. Confirmed family companions appear once as a separate person marked **(+1)**. A companion’s name can change while keeping their seat; removing the companion or +1 permission frees their seat automatically.

Use **Aggiorna RSVP e pianta** to fetch current answers and the saved plan; the editor also refreshes after dashboard guest changes. It does not subscribe to live updates. Archiving a table hides it and treats its guests as unassigned, while preserving its layout and remaining assignments for restoration under **Tavoli archiviati**. Guests reassigned elsewhere keep their new seat when the old table is restored.

Apply `20261109000004_seating_plan.sql` after the previous migrations. Seating tables have row-level security and no direct public access; dashboard functions check the admin password on every request. To run the standalone SQL regression checks, execute `supabase/tests/seating_plan.sql` as the database owner in the Supabase SQL editor. It rolls back all test records/settings and checks persistence, RSVP statuses, seat uniqueness, capacities, moves, archiving/restoration, companion cleanup, and unauthorized access. Run `npm run build` to validate the frontend.

The dashboard’s first tab contains families and invitation responses; the second contains table management. Tabs support arrow keys, Home, and End, and preserve draft fields when switching. Opening the tables tab refreshes its saved plan.

Use the **Sposta** handle next to a person to drag them from the roster, or drag an occupied seat directly. Drop on an empty numbered seat for an exact assignment, or on the table for its first available seat. Drop in the dashed unassigned area to free the person’s seat. Occupied/full destinations are rejected; dropping elsewhere or pressing Escape cancels the move. Pointer dragging supports mouse, pen, and touch, with scrolling near the plan/page edges. Selection and **Assegna posto** remain available for keyboard users. Successful drops use the same database validation and persistence as manual assignment.
