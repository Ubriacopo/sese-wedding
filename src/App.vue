<script setup lang="ts">
import {onMounted, onUnmounted, ref} from 'vue'
import PresenceForm from './components/PresenceForm.vue'
import CinemaPoster from './components/CinemaPoster.vue'
import UpcomingMovies from './components/UpcomingMovies.vue'
import {wedding} from './content/wedding'
import faqs from './content/faqs.json'

const isDark = ref(document.documentElement.dataset.theme !== 'light')
function toggleTheme() {
  isDark.value = !isDark.value
  const theme = isDark.value ? 'dark' : 'light'
  document.documentElement.dataset.theme = theme
  document.querySelector('meta[name="theme-color"]')?.setAttribute('content', isDark.value ? '#20271f' : '#f5f2e9')
  try { localStorage.setItem('wedding-theme', theme) } catch { /* The theme still works without storage. */ }
}

const activeSection = ref(window.location.hash)
const giftCopyStatus = ref('')
const ibanInput = ref<HTMLInputElement>()
async function copyGiftIban() {
  if (!wedding.gift.iban || !wedding.gift.accountHolder) return
  try {
    await navigator.clipboard.writeText(wedding.gift.iban.replace(/\s/g, ''))
    giftCopyStatus.value = 'IBAN copiato.'
  } catch {
    ibanInput.value?.focus()
    ibanInput.value?.select()
    giftCopyStatus.value = 'Selezione pronta: copia l’IBAN dal campo qui sopra.'
  }
}
const navigation = [
  { href: '#giornata', label: 'La giornata' },
  ...(wedding.upcomingMovies.length ? [{ href: '#prossimamente', label: 'Prossimamente' }] : []),
  { href: '#informazioni', label: 'Info utili' },
  { href: '#domande', label: 'FAQ' },
  { href: '#regalo', label: 'Un pensiero per noi' },
  { href: '#presenza', label: 'Ci sarai? ↗' },
]
function updateActiveSection() {
  activeSection.value = window.location.hash
}

let timelineObserver: IntersectionObserver | undefined
onMounted(() => {
  window.addEventListener('hashchange', updateActiveSection)
  const motionPreference = window.matchMedia('(prefers-reduced-motion: reduce)')
  if (motionPreference.matches || !('IntersectionObserver' in window)) return
  timelineObserver = new IntersectionObserver((entries) => {
    for (const entry of entries) {
      if (!entry.isIntersecting) continue
      if (!motionPreference.matches) {
        entry.target.animate([
          {opacity: 0.35, transform: 'translateY(16px)'},
          {opacity: 1, transform: 'translateY(0)'},
        ], {duration: 650, easing: 'cubic-bezier(0.2, 0.7, 0.2, 1)'})
      }
      timelineObserver?.unobserve(entry.target)
    }
  }, {threshold: 0.15})
  document.querySelectorAll('.screening').forEach((entry) => timelineObserver?.observe(entry))
})
onUnmounted(() => {
  timelineObserver?.disconnect()
  window.removeEventListener('hashchange', updateActiveSection)
})

const label = 'text-[10px] font-medium uppercase tracking-[0.22em] text-olive'
</script>

<template>
  <a href="#main"
     class="sr-only focus:not-sr-only focus:fixed focus:top-4 focus:left-4 focus:z-50 focus:bg-paper focus:p-4">Vai al
    contenuto</a>
  <header class="site-header mx-auto flex max-w-7xl flex-col items-start justify-between gap-3 sm:flex-row sm:items-center border-b border-line px-4 py-4 sm:gap-6 sm:px-12 sm:py-6">
    <a href="#" aria-label="Jacopo e Agnese, inizio" class="shrink-0 font-serif text-2xl italic">j<span
        class="px-1 text-olive">&</span>a</a>
    <nav aria-label="Navigazione principale" class="w-full min-w-0 sm:w-auto">
      <ul class="flex snap-x snap-proximity gap-6 overflow-x-auto overscroll-x-contain px-1 py-2 text-xs sm:flex-wrap sm:justify-end sm:gap-6">
        <li v-for="link in navigation" :key="link.href" class="shrink-0 snap-start">
          <a :href="link.href" :aria-current="activeSection === link.href ? 'location' : undefined"
             class="flex min-h-11 items-center whitespace-nowrap underline-offset-8 transition-colors focus-visible:outline-offset-2 motion-reduce:transition-none"
             :class="activeSection === link.href ? 'text-olive underline' : 'hover:text-olive hover:underline'">
            {{ link.label }}
          </a>
        </li>
      </ul>
    </nav>
    <button type="button" class="theme-toggle" :aria-pressed="isDark" aria-label="Tema scuro" @click="toggleTheme">
      <span aria-hidden="true">{{ isDark ? '◐' : '◑' }}</span> {{ isDark ? 'Luci accese' : 'Luci spente' }}
    </button>
  </header>
  <main id="main" class="[overflow-wrap:anywhere]">
    <section
        class="cinema-poster mx-auto flex min-h-[560px] max-w-7xl flex-col items-center justify-center px-4 py-16 text-center sm:px-6 sm:py-24 sm:min-h-[760px]">
      <p :class="label" class="mb-10">Una storia d’amore · Un’unica prima</p>
      <p class="mb-5 font-serif text-xl italic sm:text-2xl">{{ wedding.names }}</p>
      <h1 class="font-serif text-[clamp(2.75rem,11.5vw,10rem)] leading-[0.95] tracking-[-0.065em]">Ci sposiamo<span
          class="text-olive">.</span></h1>
      <div class="mt-12 flex flex-col items-center gap-3 text-xs sm:flex-row sm:gap-6">
        <span>{{ wedding.date || 'La data? Ve la diciamo presto.' }}</span>
        <span aria-hidden="true" class="hidden text-olive sm:block">✳</span>
        <span>{{ wedding.location || 'Il posto? Anche quello.' }}</span>
      </div>
      <div class="film-credit mt-12" aria-hidden="true"><span class="film-reel"></span><span>Una produzione<br>Jacopo &amp; Agnese</span></div>
      <a href="#giornata" class="mt-12 inline-flex min-h-11 items-center text-[10px] uppercase tracking-[0.2em] text-olive">Tutti i dettagli <span
          aria-hidden="true" class="ml-3">↓</span></a>
    </section>
    <section class="border-y border-line bg-panel px-6 py-20 text-center sm:py-24">
      <p :class="label">Con la partecipazione di tutti voi</p>
      <h2 class="mx-auto mt-6 max-w-2xl font-serif text-4xl leading-tight tracking-tight sm:text-5xl">Il nostro film più
        bello.<br>Con voi, al nostro fianco.</h2>
      <p class="mx-auto mt-7 max-w-lg text-sm leading-7 text-ink/75">Una giornata insieme alle persone a cui vogliamo
        bene. Ci saranno un sì, qualcosa di buono da mangiare e tempo per festeggiare.</p>
    </section>
    <div class="programme-wallpaper programme-projector">
    <section id="giornata" class="mx-auto max-w-6xl px-6 py-24 sm:px-12 sm:py-32">
      <div class="mb-14 flex flex-wrap items-end justify-between gap-6">
        <div><p :class="label" class="mb-5">01 / La programmazione del giorno</p>
          <h2 class="font-serif text-5xl tracking-tight sm:text-6xl">Oggi in sala</h2></div>
        <p class="max-w-xs text-sm leading-6 text-ink/65">{{ wedding.date || 'La data sarà annunciata presto.' }}<br>Quattro momenti, un’unica storia.</p>
      </div>
      <div class="programme-banner"><span>In cartellone</span><span>{{ wedding.names }} · Proiezione unica</span></div>
      <ol class="screenings">
        <li v-for="(event, index) in wedding.events" :key="event.title" class="screening">
          <article :aria-labelledby="`screening-${index}`">
            <CinemaPoster :title-id="`screening-${index}`" :title="event.title" :poster="event.poster" :tagline="event.tagline" :billing="wedding.names">
              Atto {{ String(index + 1).padStart(2, '0') }} · Solo per questa prima
            </CinemaPoster>
            <dl class="screening-details">
              <div><dt>Inizio</dt><dd>{{ event.time || 'Orario in arrivo' }}</dd></div>
              <div><dt>Sala</dt><dd>{{ event.venue || wedding.location || 'Luogo da annunciare' }}<span v-if="event.address" class="mt-1 block font-normal">{{ event.address }}</span></dd></div>
            </dl>
            <a v-if="event.mapsUrl" :href="event.mapsUrl" target="_blank" rel="noopener noreferrer"
               class="mt-4 inline-flex min-h-11 items-center border-b border-olive/50 text-xs hover:text-olive">Apri la mappa ↗</a>
          </article>
        </li>
      </ol>
    </section>
    </div>
    <div v-if="wedding.upcomingMovies.length" aria-hidden="true" class="h-12 border-y border-line bg-paper sm:h-16"></div>
    <div class="programme-wallpaper">
    <section v-if="wedding.upcomingMovies.length" id="prossimamente" class="mx-auto max-w-6xl px-6 pt-12 pb-12 sm:px-12 sm:pt-16 sm:pb-16" aria-labelledby="upcoming-title">
      <div class="mb-6 flex flex-wrap items-end justify-between gap-4">
        <div><p :class="label" class="mb-5">02 / Le prossime uscite</p>
          <h2 id="upcoming-title" class="font-serif text-4xl tracking-tight sm:text-5xl">Prossimamente</h2></div>
        <p class="max-w-xs text-sm leading-7 text-ink/65">Grandi emozioni, due protagonisti.<br>Il nostro cinema continua.</p>
      </div>
      <UpcomingMovies :movies="wedding.upcomingMovies" />
    </section>
    </div>
    <section id="informazioni" class="border-y border-line">
      <div class="mx-auto grid max-w-6xl gap-12 px-6 py-24 sm:px-12 md:grid-cols-[minmax(0,1fr)_minmax(0,1.2fr)] md:gap-12 lg:gap-24">
        <div><p :class="label" class="mb-5">03 / Per organizzarsi</p>
          <h2 class="font-serif text-5xl leading-tight tracking-tight">Le cose<br>da sapere.</h2>
          <p class="mt-7 max-w-xs text-sm leading-7 text-ink/65">Raccoglieremo qui le informazioni pratiche, così avrete
            tutto a portata di mano.</p></div>
        <div class="space-y-9">
          <article class="border-b border-line pb-9"><h3 class="font-serif text-2xl">Come arrivare</h3>
            <p class="mt-4 text-sm leading-7 text-ink/65">
              {{ wedding.travel || 'Presto qui troverete indicazioni, parcheggi e consigli per raggiungerci.' }}</p>
          </article>
          <article><h3 class="font-serif text-2xl">Dove fermarsi</h3>
            <p class="mt-4 text-sm leading-7 text-ink/65">{{
                wedding.accommodation || 'Venite da lontano? Aggiungeremo qualche suggerimento per dormire in zona.'
              }}</p></article>
        </div>
      </div>
    </section>
    <section id="domande" class="programme-wallpaper px-6 py-24 sm:px-12">
      <div class="cinema-board mx-auto max-w-[1056px]">
        <header class="cinema-board-header">
          <p class="cinema-eyebrow">04 / Prima di entrare in sala</p>
          <h2>In programma</h2>
          <p>Domande, risposte e altre scene utili.</p>
          <div class="marquee-stars" aria-hidden="true">★ ★ ★</div>
        </header>
        <div class="board-columns" aria-hidden="true"><span>Sala</span><span>Le vostre domande</span><span class="listing-desktop-heading">Orario</span><span class="listing-desktop-heading">Posti liberi</span><span>Info</span></div>
        <div class="cinema-listings">
          <details v-for="(faq, index) in faqs" :id="faq.id" :key="faq.id" name="cinema-faq" class="cinema-listing">
            <summary>
              <span class="listing-number" aria-hidden="true">{{ String(index + 1).padStart(2, '0') }}</span>
              <span class="listing-title">{{ faq.question }}<span v-if="faq.subtitle" class="listing-subtitle">{{ faq.subtitle }}</span></span>
              <span class="listing-showing" aria-hidden="true">
                <span class="listing-showtime"><span class="listing-mobile-label">Ore </span>{{ faq.showtime }}</span>
                <span class="listing-seats"><span class="seat-light"></span>{{ faq.seatsLeft }}<span class="listing-mobile-label"> posti liberi</span></span>
              </span>
              <span class="listing-action" aria-hidden="true">+</span>
            </summary>
            <div class="listing-answer [&_a]:underline [&_a]:underline-offset-4 [&_ol]:list-decimal [&_ol]:pl-5 [&_ul]:list-disc [&_ul]:pl-5" v-html="faq.answerHtml"></div>
          </details>
        </div>
        <p class="board-scene-note">Orari e posti liberi sono dettagli di scena.</p>
        <footer class="cinema-board-footer"><span>{{ wedding.names }} · La prima</span><a href="#presenza">Il tuo biglietto ↗</a></footer>
      </div>
    </section>
    <section id="presenza" class="cinema-foyer px-6 py-24 sm:px-12 sm:py-28">
      <div class="mx-auto grid max-w-6xl items-start gap-12 lg:grid-cols-[minmax(0,0.8fr)_minmax(0,1.2fr)] lg:gap-20">
        <div><p class="text-[10px] uppercase tracking-[0.22em] text-[#f5f2e9]/70">05 / La biglietteria</p>
          <h2 class="mt-6 font-serif text-6xl tracking-tight sm:text-7xl">Ci sarai?</h2>
          <p class="mt-6 max-w-md text-sm leading-7 text-[#f5f2e9]/80">La compagnia è la parte più bella.<br>{{
              wedding.rsvpDeadline ? `Conferma entro il ${wedding.rsvpDeadline}.` : 'Presto ti diremo entro quando confermare.'
            }}</p>
          <div class="mt-10 ticket-caption"><span aria-hidden="true">✳</span><span class="font-serif text-xl italic">Questa prima è anche tua.</span></div>
        </div>
        <PresenceForm/>
      </div>
    </section>
    <section id="regalo" class="programme-wallpaper border-b border-line px-6 py-24 sm:px-12 sm:py-32" aria-labelledby="gift-title">
      <div class="gift-credits mx-auto max-w-3xl">
        <p class="cinema-eyebrow">06 / Dopo i titoli di coda</p>
        <div class="gift-stars" aria-hidden="true">★ ★ ★</div>
        <h2 id="gift-title" class="font-serif text-4xl leading-tight tracking-tight sm:text-6xl">{{ wedding.gift.title }}</h2>
        <p class="mx-auto mt-7 max-w-lg text-sm leading-7 text-[#f5f2e9]/80">{{ wedding.gift.message }}</p>
        <dl class="gift-cast">
          <div><dt>Protagonisti</dt><dd>{{ wedding.names }}</dd></div>
          <div><dt>Con la partecipazione straordinaria di</dt><dd>Tutti voi</dd></div>
          <div><dt>Le prossime scene</dt><dd>Ancora tutte da vivere</dd></div>
        </dl>
        <div v-if="wedding.gift.iban && wedding.gift.accountHolder" class="gift-bank">
          <p class="ticket-kicker mb-5">Un pensiero per il nostro seguito</p>
          <dl class="space-y-5">
            <div><dt class="gift-bank-label">Intestatario</dt><dd class="mt-1 text-sm">{{ wedding.gift.accountHolder }}</dd></div>
            <div>
              <dt><label for="gift-iban" class="gift-bank-label">IBAN</label></dt>
              <dd><input id="gift-iban" ref="ibanInput" :value="wedding.gift.iban" readonly spellcheck="false" class="gift-iban" /></dd>
            </div>
            <div v-if="wedding.gift.reference"><dt class="gift-bank-label">Causale</dt><dd class="mt-1 text-sm leading-6">{{ wedding.gift.reference }}</dd></div>
          </dl>
          <button type="button" class="mt-6 inline-flex min-h-12 items-center justify-center border border-[#697252] px-6 py-3 text-xs uppercase tracking-widest hover:bg-[#e0e2d2] focus-visible:outline-[#697252]" @click="copyGiftIban">Copia IBAN <span class="ml-3" aria-hidden="true">↗</span></button>
          <p role="status" aria-live="polite" class="mt-3 text-sm leading-6">{{ giftCopyStatus }}</p>
        </div>
        <p v-else class="gift-placeholder">{{ wedding.gift.placeholder }}</p>
        <p class="mt-10 font-serif text-2xl italic text-[#c0c7a8]">Il bello deve ancora venire.</p>
      </div>
    </section>
  </main>
  <footer class="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-5 px-6 py-8 sm:px-12">
    <p class="font-serif text-lg italic">{{ wedding.names }}</p>
    <p class="text-[10px] uppercase tracking-[0.18em] text-olive">Ci vediamo in sala.</p>
    <a href="#" class="inline-flex min-h-11 items-center text-xs text-olive">Torna su ↑</a>
  </footer>
</template>
