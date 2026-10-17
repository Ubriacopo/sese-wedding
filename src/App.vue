<script setup lang="ts">
import {onMounted, onUnmounted, ref} from 'vue'
import PresenceForm from './components/PresenceForm.vue'
import {wedding} from './content/wedding'
import faqs from './content/faqs.json'

const activeSection = ref(window.location.hash)
const navigation = [
  { href: '#giornata', label: 'La giornata' },
  ...(wedding.showStory ? [{ href: '#storia', label: 'La nostra storia' }] : []),
  { href: '#domande', label: 'FAQ' },
  { href: '#informazioni', label: 'Info utili' },
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
  document.querySelectorAll('.timeline-entry').forEach((entry) => timelineObserver?.observe(entry))
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
  <header class="mx-auto flex max-w-7xl flex-col items-start justify-between gap-3 sm:flex-row sm:items-center border-b border-line px-4 py-4 sm:gap-6 sm:px-12 sm:py-6">
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
  </header>
  <main id="main" class="[overflow-wrap:anywhere]">
    <section
        class="mx-auto flex min-h-[560px] max-w-7xl flex-col items-center justify-center px-4 py-16 text-center sm:px-6 sm:py-24 sm:min-h-[760px]">
      <p :class="label" class="mb-10">La nostra prossima mossa</p>
      <p class="mb-5 font-serif text-xl italic sm:text-2xl">{{ wedding.names }}</p>
      <h1 class="font-serif text-[clamp(2.75rem,11.5vw,10rem)] leading-[0.95] tracking-[-0.065em]">Ci sposiamo<span
          class="text-olive">.</span></h1>
      <div class="mt-12 flex flex-col items-center gap-3 text-xs sm:flex-row sm:gap-6">
        <span>{{ wedding.date || 'La data? Ve la diciamo presto.' }}</span>
        <span aria-hidden="true" class="hidden text-olive sm:block">✳</span>
        <span>{{ wedding.location || 'Il posto? Anche quello.' }}</span>
      </div>
      <div class="board-emblem mt-12" aria-hidden="true"><span
          class="die"><i></i><i></i><i></i><i></i><i></i></span><span class="emblem-path"></span><span
          class="playing-piece"></span></div>
      <a href="#giornata" class="mt-12 inline-flex min-h-11 items-center text-[10px] uppercase tracking-[0.2em] text-olive">Tutti i dettagli <span
          aria-hidden="true" class="ml-3">↓</span></a>
    </section>
    <section class="border-y border-line bg-[#e9ecdf] px-6 py-20 text-center sm:py-24">
      <p :class="label">Al tavolo, insieme</p>
      <h2 class="mx-auto mt-6 max-w-2xl font-serif text-4xl leading-tight tracking-tight sm:text-5xl">La partita più
        bella.<br>Con voi, al nostro fianco.</h2>
      <p class="mx-auto mt-7 max-w-lg text-sm leading-7 text-ink/75">Una giornata insieme alle persone a cui vogliamo
        bene. Ci saranno un sì, qualcosa di buono da mangiare e tempo per festeggiare.</p>
    </section>
    <section id="giornata" class="mx-auto max-w-6xl px-6 py-24 sm:px-12 sm:py-32">
      <div class="mb-14 flex flex-wrap items-end justify-between gap-6">
        <div><p :class="label" class="mb-5">01 / Il programma</p>
          <h2 class="font-serif text-5xl tracking-tight sm:text-6xl">La giornata</h2></div>
        <p class="max-w-xs text-sm leading-6 text-ink/65">I momenti importanti, i posti giusti.<br>Gli orari arriveranno
          presto.</p>
      </div>
      <ol class="vertical-timeline">
        <li v-for="(event, index) in wedding.events" :key="event.title" class="timeline-entry">
          <span class="timeline-marker" aria-hidden="true">{{ String(index + 1).padStart(2, '0') }}</span>
          <p :class="label" class="mb-3">{{ event.time || 'Orario in arrivo' }}</p>
          <h3 class="font-serif text-3xl">{{ event.title }}</h3>
          <p class="mt-5 text-sm font-medium">{{ event.venue || wedding.location || 'Luogo da annunciare' }}</p>
          <p v-if="event.address" class="mt-2 text-sm text-ink/65">{{ event.address }}</p>
          <p class="mt-4 max-w-sm text-sm leading-7 text-ink/65">{{ event.note }}</p>
          <a v-if="event.mapsUrl" :href="event.mapsUrl" target="_blank" rel="noopener noreferrer"
             class="mt-6 inline-flex min-h-11 items-center border-b border-olive/50 pb-1 text-xs hover:text-olive">Apri la mappa ↗</a>
        </li>
      </ol>
    </section>
    <section v-if="wedding.showStory" id="storia" class="border-y border-line bg-[#e9ecdf] px-6 py-24 sm:px-12">
      <div class="mx-auto max-w-6xl">
        <p :class="label" class="mb-5">02 / Le nostre tappe</p>
        <div class="mb-14 flex flex-wrap items-end justify-between gap-6"><h2
            class="font-serif text-5xl tracking-tight sm:text-6xl">Una mossa alla volta.</h2>
          <p class="max-w-xs text-sm leading-7 text-ink/70">Prima di questo giorno, tanti piccoli inizi.<br>E ancora
            tante caselle da scoprire.</p></div>
        <ol class="vertical-timeline story-timeline">
          <li v-for="(moment, index) in wedding.story" :key="moment.title" class="timeline-entry">
            <span class="timeline-marker" aria-hidden="true">{{ String(index + 1).padStart(2, '0') }}</span>
            <p :class="label" class="mb-3">{{ moment.date }}</p>
            <h3 class="font-serif text-3xl">{{ moment.title }}</h3>
            <p class="mt-5 text-sm leading-7 text-ink/75">{{ moment.note }}</p>
          </li>
        </ol>
      </div>
    </section>
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
    <section id="domande" class="mx-auto max-w-6xl px-6 py-24 sm:px-12">
      <div class="rulebook">
        <header class="rulebook-header">
          <div><p :class="label" class="mb-4">04 / Il manuale della giornata</p>
            <h2 class="font-serif text-[clamp(5rem,16vw,9rem)] leading-none tracking-tight">FAQ<span class="text-olive">.</span>
            </h2></div>
          <p class="max-w-xs text-sm leading-7 text-ink/75">Le cose da sapere, prima di prendere posto.<br>Un piccolo
            regolamento per godersi la giornata.</p>
        </header>
        <div class="rulebook-articles">
          <article v-for="(faq, index) in faqs" :id="faq.id" :key="faq.id"
                   class="rulebook-article">
            <h3 class="font-title text-base font-semibold uppercase leading-snug tracking-[0.06em] sm:text-lg"><span class="rule-number">{{ index + 1 }}.</span> {{ faq.question }}</h3>
            <p v-if="faq.subtitle" class="mt-0.5 text-xs leading-4 text-stone-500">{{ faq.subtitle }}</p>
            <div class="mt-2 space-y-2 text-sm leading-[1.85] [&_a]:underline [&_a]:underline-offset-4 [&_ol]:list-decimal [&_ol]:pl-5 [&_ul]:list-disc [&_ul]:pl-5" v-html="faq.answerHtml"></div>
          </article>
        </div>
        <footer class="rulebook-footer"><span>Jacopo &amp; Agnese · Il manuale</span><a href="#presenza"
                                                                                        class="inline-flex min-h-11 items-center underline underline-offset-4 hover:text-ink">Il
          tuo posto al tavolo ↗</a></footer>
      </div>
    </section>
    <section id="presenza" class="bg-ink px-6 py-24 text-paper sm:px-12 sm:py-28">
      <div class="mx-auto grid max-w-6xl items-start gap-12 lg:grid-cols-[minmax(0,0.8fr)_minmax(0,1.2fr)] lg:gap-20">
        <div><p class="text-[10px] uppercase tracking-[0.22em] text-paper/70">05 / Il tuo posto al tavolo</p>
          <h2 class="mt-6 font-serif text-6xl tracking-tight sm:text-7xl">Ci sarai?</h2>
          <p class="mt-6 max-w-md text-sm leading-7 text-paper/80">La compagnia è la parte più bella.<br>{{
              wedding.rsvpDeadline ? `Conferma entro il ${wedding.rsvpDeadline}.` : 'Presto ti diremo entro quando confermare.'
            }}</p>
          <div class="mt-10 flex items-center gap-4 text-paper/70" aria-hidden="true"><span
              class="playing-piece"></span><span class="h-px w-20 bg-paper/30"></span><span
              class="font-serif text-xl italic">Un posto per te.</span></div>
        </div>
        <PresenceForm/>
      </div>
    </section>
  </main>
  <footer class="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-5 px-6 py-8 sm:px-12">
    <p class="font-serif text-lg italic">{{ wedding.names }}</p>
    <p class="text-[10px] uppercase tracking-[0.18em] text-olive">Ci vediamo lì.</p>
    <a href="#" class="inline-flex min-h-11 items-center text-xs text-olive">Torna su ↑</a>
  </footer>
</template>
