# sese-wedding

Jacopo & Agnese’s wedding website, built with Vue 3, TypeScript, Vite and Tailwind CSS.

Use Node.js 22.22.2+ or 24.15+. Run `npm install` and `npm run dev` to develop; `npm run build` to type-check and build for production.

Edit `src/content/wedding.ts` for names, date, location, schedule, travel, accommodation and RSVP details. Empty fields display placeholder copy. Map links appear when `mapsUrl` is set. Set `rsvpEmail` to enable confirmation by email; the website does not store responses.

The layout is in `src/App.vue`. Tailwind theme tokens and minimal global styles are in `src/assets/main.css`. The FAQ titles use the locally hosted Cinzel font; its license is included in `public/fonts`. No external services are needed.

The cinema programme uses `events` in `src/content/wedding.ts`. Event stages are illustrative; update them to match the actual schedule.

The RSVP form lives in `src/components/PresenceForm.vue`. It collects a single name, attendance and optional notes. Guests do not need to enter an email address. Without `rsvpEmail`, submission is a clearly labelled preview and does not send or save data. With `rsvpEmail`, submission opens a prefilled email that the guest must send. Replace `submitPresence` with a backend adapter when adding Supabase; implement server-side validation and appropriate access controls before enabling storage.

Personalize an invitation link with `?name=Mario&surname=Rossi#presenza`, for example `https://ubriacopo.github.io/sese-wedding/?name=Mario&surname=Rossi#presenza`. Both parameters are optional; `?name=Mario%20Rossi#presenza` also works. Names are combined into the editable name field, with whitespace normalized and a 160-character limit. Use `URLSearchParams` when generating links to encode spaces, accents and special characters correctly. Without these parameters, the name field stays empty. The `#presenza` fragment opens the ticket directly. URL parameters are visible and editable, so they prefill the form without authenticating a guest; no guest list is embedded in the site.

Submitting an attending response adds a random cinema hall (1–4), seat (1–20, A–H) and a Code 39 barcode to the ticket stub, preserving its original text and stamp. The barcode is hidden below 640px width or at viewport heights of 600px or less to keep the original information and seating details readable. These are theatrical decorations, generated once per page session and retained when editing the response. They are not actual seating assignments or admission credentials, are not guaranteed unique, and are not persisted on reload. Non-attending responses keep the original stub. When adding a backend, persist ticket details with the RSVP and reveal them after a successful save; the current preview/email flow does not verify confirmation.

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
