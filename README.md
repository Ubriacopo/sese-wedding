# sese-wedding

Jacopo & Agnese’s wedding website, built with Vue 3, TypeScript, Vite and Tailwind CSS.

Use Node.js 22.22.2+ or 24.15+. Run `npm install` and `npm run dev` to develop; `npm run build` to type-check and build for production.

Edit `src/content/wedding.ts` for names, date, location, schedule, travel, accommodation and RSVP details. Empty fields display placeholder copy. Map links appear when `mapsUrl` is set. Set `rsvpEmail` to enable confirmation by email; the website does not store responses.

The layout is in `src/App.vue`. Tailwind theme tokens and minimal global styles are in `src/assets/main.css`. The FAQ titles use the locally hosted Cinzel font; its license is included in `public/fonts`. No external services are needed.

The event timeline uses `events` in `src/content/wedding.ts`. Edit `story` to replace the sample milestones with your own memories, or set `showStory: false` to hide the section and its navigation link. Event stages are illustrative; update them to match the actual schedule.

The RSVP form lives in `src/components/PresenceForm.vue`. It collects first name, surname, email, attendance, party size, additional guest names, dietary requirements and a message. Without `rsvpEmail`, submission is a clearly labelled preview and does not send or save data. With `rsvpEmail`, submission opens a prefilled email that the guest must send. Replace `submitPresence` with a backend adapter when adding Supabase; implement server-side validation and appropriate access controls before enabling storage.

Edit `src/content/faqs.json` to add, remove or reorder FAQs. Each entry has a unique `id` (also used for its anchor), a plain-text `question`, an optional plain-text `subtitle` (omit it or leave it empty to hide it), and an `answerHtml` string. Answers render as HTML, so you can add paragraphs, links, lists and Tailwind classes. Keep this HTML authored in the repository; it is rendered directly without sanitization. Escape double quotes inside JSON strings, for example:

```json
{
  "id": "faq-parcheggio",
  "question": "Dove posso parcheggiare?",
  "answerHtml": "<p>Il parcheggio è <strong>gratuito</strong>.</p><p class=\"mt-4 text-olive\">Segui le indicazioni all’ingresso.</p>"
}
```

FAQ column layout and spacing can be adjusted in `src/App.vue` and the existing rulebook styles in `src/assets/main.css`. Changes to the JSON are included on the next build.

## GitHub Pages

The site deploys to https://ubriacopo.github.io/sese-wedding/ through `.github/workflows/deploy.yml`. In the GitHub repository, select **Settings → Pages → Build and deployment → Source → GitHub Actions** once. Every push to `master` then installs dependencies, checks types, builds the site and deploys `dist/`. You can also run the workflow manually from the Actions tab.

Vite's `base` is `/sese-wedding/` to match the repository path. Update it if the repository name changes; use `/` when moving to a custom domain. Commit `package-lock.json` and `env.d.ts` so the deployment can install and type-check the project. Keep `dist/` and `node_modules/` out of Git.
