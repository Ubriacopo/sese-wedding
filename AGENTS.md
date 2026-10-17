# Repository Guidelines

## Project Structure & Module Organization

This is a single-page wedding website built with Vue 3, TypeScript, Vite, and Tailwind CSS 4.

- `src/main.ts` mounts the application and imports global styles.
- `src/App.vue` contains the page layout and rendering logic.
- `src/content/wedding.ts` holds names, dates, venues, travel information, FAQs, and RSVP settings. Make content changes here first.
- `src/assets/main.css` defines Tailwind theme tokens and global styles.
- `public/` contains static assets, including the favicon; `index.html` is the HTML entry point.
- `vite.config.ts` and `tsconfig*.json` configure the toolchain. `dist/` is generated build output.

## Build, Test, and Development Commands

Use a Node.js version satisfying `^22.22.2 || >=24.15.0` and npm.

- `npm ci`: install dependencies from `package-lock.json`.
- `npm run dev`: start the Vite development server.
- `npm run type-check`: check TypeScript and Vue components with `vue-tsc`.
- `npm run build`: run type checking and the production build in parallel.
- `npm run build-only`: generate the production bundle without type checking.
- `npm run preview`: serve the built site locally for review.

## Coding Style & Naming Conventions

Match existing two-space indentation, single-quoted TypeScript strings, and omitted JavaScript semicolons. Use Vue single-file components with `<script setup lang="ts">`; use PascalCase component filenames and camelCase variables and content fields. The `@/` alias resolves to `src/`.

Prefer Tailwind utilities for layout and existing theme tokens for colors and fonts. Keep guest-facing copy in Italian. No formatter or linter is currently configured; follow nearby code.

## Testing Guidelines

No automated test framework, test script, or coverage target is configured. Run `npm run build` before submitting changes. Review mobile and desktop layouts, keyboard navigation, FAQ disclosure controls, anchor links, and conditional map and RSVP links. Check both empty content placeholders and populated fields. If adding tests, document the chosen framework, naming convention, and command.

## Commit & Pull Request Guidelines

Git metadata is absent from this checkout, so existing commit conventions cannot be verified. Use concise, imperative messages such as `Fix mobile navigation spacing`.

Pull requests should describe the change, link relevant issues, and list validation performed. Include mobile and desktop screenshots for visual changes. Keep generated output and dependencies out of source changes.

## Content & Configuration

RSVP uses an email link and does not store responses. Values in `wedding.ts` ship to visitors: include only information intended for public display, and never add secrets.
