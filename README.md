# sese-wedding

Jacopo & Agnese’s wedding website, built with Vue 3, TypeScript, Vite and Tailwind CSS. The design treats the wedding as a new TV season: a featured original series, four episodes, a DVD-by-mail invitation, and a streaming help centre.

Use Node.js satisfying `^22.22.2 || >=24.15.0` and npm. Run `npm ci`, `npm run dev`, and `npm run build` to type-check and build for production. In PowerShell environments that block npm.ps1, use `npm.cmd`.

Edit `src/content/wedding.ts` for names, date, location, series and invitation copy, schedule, travel, accommodation, gifts and RSVP settings. Empty fields display placeholders. Map links appear when an event’s `mapsUrl` is set. Episode illustrations are in `src/components/EpisodeArtwork.vue`; available art keys are `ceremony`, `toast`, `dinner` and `party`.

The layout is in `src/App.vue`, and Tailwind tokens and responsive styles are in `src/assets/main.css`. Dark and light themes use the same burgundy accent; the selected theme is retained locally when storage is available. The invitation envelope is a CSS illustration and concept preview, not a print-ready invitation or downloadable file. The old movie catalogue and poster components remain in the repository for reference and are not displayed.

## RSVP

The form is in `src/components/PresenceForm.vue`. It collects name, attendance and optional notes. Set `rsvpEmail` to open a prefilled email that the guest must send to complete confirmation. The website does not store responses. Without an email address, the form is clearly labelled as a preview and does not send or save data. `rsvpDeadline` is optional.

Personalize links with `?name=Mario&surname=Rossi#presenza`, for example `https://ubriacopo.github.io/sese-wedding/?name=Mario&surname=Rossi#presenza`. Both parameters are optional. Use `URLSearchParams` to encode names correctly. The editable name is normalized and limited to 160 characters. Parameters can also be appended after the fragment (`#presenza?name=Mario`). These links prefill the form; they do not authenticate guests.

## FAQs and gifts

Edit `src/content/faqs.json` to add, remove or reorder questions. Each entry has a unique `id` (also its anchor), a plain-text `question`, an optional plain-text `subtitle`, and `answerHtml`. HTML is rendered directly: keep it authored in the repository. Old decorative showtimes and seat counts have been removed.

The FAQs form a series called “Centro assistenza”, with its own cover and an episode list. Each question is an expandable episode; its answer appears when opened. Edit `helpSeries` in `wedding.ts` for the title, genre, synopsis and season label. Episode counts and numbering follow the FAQ array automatically.

Configure `gift` in `wedding.ts`. Both `iban` and `accountHolder` must be populated to display bank details and the copy button. Otherwise the placeholder is shown. The optional `reference` is displayed when set. Clipboard failure selects the IBAN for manual copying.

## Local preview and deployment

The development server listens at `http://localhost:5173/sese-wedding/`; `npm run preview` serves the production build at port 4173. Both listen on all IPv4 interfaces with fixed ports. On your local network use your PC’s IP address in place of localhost.

If Windows Firewall blocks local network access, run `powershell -ExecutionPolicy RemoteSigned -File .\scripts\Enable-LocalNetwork.ps1` from an administrator terminal. It allows TCP 5173 and 4173 from the local subnet. Remove the rule with `Remove-NetFirewallRule -Name SeseWedding-LocalNetwork` if needed.

GitHub Pages deploys to https://ubriacopo.github.io/sese-wedding/ via `.github/workflows/deploy.yml`. Select GitHub Actions as the Pages source in repository settings. Pushes to `master` build and deploy `dist/`; manual workflow runs are also supported. Vite’s base is `/sese-wedding/`; change it for another repository path or a custom domain. Keep generated output and dependencies out of source changes.

## Validation

Run `npm run build` before submitting changes. Review desktop and mobile widths, light and dark themes, keyboard focus, native FAQ disclosures, navigation anchors, name-prefilled RSVP preview/email flows, and empty/populated map and gift settings. No automated test framework is configured.
