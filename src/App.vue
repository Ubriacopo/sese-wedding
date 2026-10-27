<script setup lang="ts">
import { onMounted, onUnmounted, ref } from 'vue'
import PresenceForm from './components/PresenceForm.vue'
import EpisodeArtwork from './components/EpisodeArtwork.vue'
import { wedding } from './content/wedding'
import faqs from './content/faqs.json'

const isDark = ref(document.documentElement.dataset.theme !== 'light')
const activeSection = ref(window.location.hash)
const giftCopyStatus = ref('')
const ibanInput = ref<HTMLInputElement>()
const navigation = [
  { href: '#giornata', label: 'Gli episodi' },
  { href: '#invito', label: 'L’invito' },
  { href: '#informazioni', label: 'Info utili' },
  { href: '#domande', label: 'Assistenza' },
  { href: '#regalo', label: 'Un pensiero per noi' },
]
function toggleTheme() {
  isDark.value = !isDark.value
  const theme = isDark.value ? 'dark' : 'light'
  document.documentElement.dataset.theme = theme
  document.querySelector('meta[name="theme-color"]')?.setAttribute('content', isDark.value ? '#141414' : '#f6f3ed')
  try { localStorage.setItem('wedding-theme', theme) } catch { /* Theme works without storage. */ }
}
function updateActiveSection() { activeSection.value = window.location.hash }
onMounted(() => window.addEventListener('hashchange', updateActiveSection))
onUnmounted(() => window.removeEventListener('hashchange', updateActiveSection))
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
</script>

<template>
  <a href="#main" class="skip-link">Vai al contenuto</a>
  <header class="site-header page-width">
    <a href="#" class="brand" :aria-label="`${wedding.names}, inizio`">{{ wedding.series.brand }}<span>LA NOSTRA SERIE</span></a>
    <nav aria-label="Navigazione principale">
      <a v-for="link in navigation" :key="link.href" :href="link.href" :aria-current="activeSection === link.href ? 'location' : undefined">{{ link.label }}</a>
    </nav>
    <button type="button" class="theme-toggle" :aria-pressed="isDark" aria-label="Tema scuro" @click="toggleTheme">{{ isDark ? '☀' : '☾' }}<span class="sr-only">Cambia tema</span></button>
  </header>
  <main id="main">
    <section class="series-hero page-width" aria-labelledby="series-title">
      <div class="hero-copy">
        <p class="eyebrow"><span class="original-mark">J&A</span> UNA SERIE ORIGINALE</p>
        <p class="hero-names">{{ wedding.names }} presentano</p>
        <h1 id="series-title">La nostra<br>prossima<br><em>stagione.</em></h1>
        <div class="series-meta"><span class="match">Una storia da vivere insieme</span><span>2027</span><span class="meta-badge">Sì</span><span>1 giorno · 4 episodi</span></div>
        <p class="hero-description">{{ wedding.series.description }}</p>
        <div class="hero-actions"><a href="#presenza" class="button button-primary"><span aria-hidden="true">▶</span> Ci sarò</a><a href="#giornata" class="button button-secondary"><span aria-hidden="true">ⓘ</span> Scopri gli episodi</a></div>
        <p class="hero-date">{{ wedding.date || 'Data da annunciare' }}<span> {{ wedding.location || 'Luogo da annunciare' }}</span></p>
      </div>
      <div class="hero-art" aria-hidden="true">
        <div class="art-topline"><span>J&A ORIGINAL</span><span>01 / ∞</span></div>
        <div class="orbit orbit-one"></div><div class="orbit orbit-two"></div>
        <div class="art-monogram">J<span>&</span>A</div>
        <div class="art-caption"><span>OGNI STAGIONE CI HA PORTATI QUI.</span><strong>Il bello<br>deve ancora venire.</strong><span>UNA NUOVA STAGIONE · {{ wedding.date || 'PROSSIMAMENTE' }}</span></div>
        <span class="art-side">ROMANTICO · COMMEDIA · VITA VERA</span>
      </div>
    </section>
    <section id="giornata" class="section page-width" aria-labelledby="episodes-title">
      <div class="section-heading"><div><p class="eyebrow">La stagione del sì</p><h2 id="episodes-title">Gli episodi della giornata</h2></div><span class="season-selector">Stagione 1</span></div>
      <p class="section-intro">Dalla prima emozione all’ultimo ballo. Questa volta, niente tasto pausa.</p>
      <ol class="episode-grid">
        <li v-for="(event, index) in wedding.events" :key="event.title" class="episode-card">
          <div class="episode-visual"><EpisodeArtwork :art="event.poster" /><span class="episode-number" aria-hidden="true">{{ String(index + 1).padStart(2, '0') }}</span></div>
          <div class="episode-title"><h3>{{ event.title }}</h3><span>{{ event.time || 'Orario in arrivo' }}</span></div>
          <p class="episode-tagline">{{ event.tagline }}</p>
          <p class="episode-venue">{{ event.venue || wedding.location || 'Luogo da annunciare' }}<span v-if="event.address"> · {{ event.address }}</span></p>
          <a v-if="event.mapsUrl" :href="event.mapsUrl" target="_blank" rel="noopener noreferrer" class="text-link">Apri la mappa ↗</a>
        </li>
      </ol>
    </section>
    <section id="invito" class="invitation-section">
      <div class="page-width invitation-grid">
        <div><p class="eyebrow">Prima dello streaming, una busta speciale</p><h2>{{ wedding.series.invitationTitle }}</h2><p>{{ wedding.series.invitationMessage }}</p><p class="muted">Un piccolo ritorno ai DVD per posta, per una storia che continua dal vivo.</p><a href="#presenza" class="text-link">Conferma la tua presenza <span aria-hidden="true">↗</span></a></div>
        <div class="mailer" aria-label="Invito ispirato a una busta per DVD per posta">
          <div class="mailer-top"><strong>{{ wedding.series.brand }}</strong><span>UN INVITO ORIGINALE</span></div>
          <div class="mailer-insert"><span class="eyebrow">IN ARRIVO NELLA VOSTRA VITA</span><strong>{{ wedding.names }}</strong><p>{{ wedding.series.title }}</p><div class="disc" aria-hidden="true"><span>J&A<br>LA STAGIONE DEL SÌ</span></div></div>
          <div class="mailer-envelope"><span>CONSEGNA SPECIALE / {{ wedding.date || 'DATA IN ARRIVO' }}</span><strong>Ci sposiamo.<br>Voi ci siete?</strong><div><span>{{ wedding.location || 'Luogo da annunciare' }}</span><span aria-hidden="true">↗</span></div></div>
        </div>
      </div>
    </section>
    <section id="informazioni" class="section page-width" aria-labelledby="info-title">
      <div class="section-heading"><div><p class="eyebrow">Tutto pronto per la première?</p><h2 id="info-title">Prima di premere play</h2></div></div>
      <div class="info-grid"><article><span class="info-icon" aria-hidden="true">↗</span><h3>Come arrivare</h3><p>{{ wedding.travel || 'Presto qui troverete indicazioni, parcheggi e consigli per raggiungerci.' }}</p></article><article><span class="info-icon" aria-hidden="true">⌂</span><h3>Dove fermarsi</h3><p>{{ wedding.accommodation || 'Venite da lontano? Aggiungeremo qualche suggerimento per dormire in zona.' }}</p></article></div>
    </section>
    <section id="domande" class="help-section section page-width" aria-labelledby="faq-title">
      <div class="help-intro">
        <div class="help-cover">
          <p class="eyebrow"><span class="original-mark">{{ wedding.series.brand }}</span> UNA SERIE ORIGINALE</p>
          <span class="help-cover-mark" aria-hidden="true">?</span>
          <h2 id="faq-title">{{ wedding.helpSeries.title }}</h2>
          <p class="help-cover-genre">{{ wedding.helpSeries.genre }}</p>
        </div>
        <div class="help-series-meta"><span>{{ wedding.helpSeries.season }}</span><span>{{ faqs.length }} episodi</span><span>Per tutti gli invitati</span></div>
        <p>{{ wedding.helpSeries.description }}</p>
      </div>
      <div class="faq-list">
        <div class="faq-season-heading"><h3>Episodi</h3><span>{{ wedding.helpSeries.season }} · F.A.Q.</span></div>
        <details v-for="(faq, index) in faqs" :id="faq.id" :key="faq.id" name="streaming-faq">
          <summary>
            <span class="faq-number" aria-hidden="true">{{ String(index + 1).padStart(2, '0') }}</span>
            <span class="faq-episode-copy"><span class="faq-episode-label">Episodio {{ index + 1 }}</span>{{ faq.question }}<small v-if="faq.subtitle">{{ faq.subtitle }}</small></span>
            <span class="faq-action" aria-hidden="true">+</span>
          </summary>
          <div class="faq-answer [&_a]:underline [&_a]:underline-offset-4 [&_ol]:list-decimal [&_ol]:pl-5 [&_ul]:list-disc [&_ul]:pl-5" v-html="faq.answerHtml"></div>
        </details>
      </div>
    </section>
    <section class="rsvp-section"><div class="page-width rsvp-grid"><div><p class="eyebrow">Il cast è quasi al completo</p><h2>Ci sei anche tu?</h2><p>Le nostre persone preferite, tutte nella stessa puntata.</p><p class="muted">{{ wedding.rsvpDeadline ? `Conferma entro il ${wedding.rsvpDeadline}.` : 'Presto ti diremo entro quando confermare.' }}</p><div class="rsvp-motif" aria-hidden="true">J<span>+</span>A<span>+</span>VOI</div></div><PresenceForm /></div></section>
    <section id="regalo" class="section page-width gift-section" aria-labelledby="gift-title"><p class="eyebrow">La storia continua</p><h2 id="gift-title">{{ wedding.gift.title }}</h2><p>{{ wedding.gift.message }}</p>
      <div v-if="wedding.gift.iban && wedding.gift.accountHolder" class="gift-bank"><dl><div><dt>Intestatario</dt><dd>{{ wedding.gift.accountHolder }}</dd></div><div><dt><label for="gift-iban">IBAN</label></dt><dd><input id="gift-iban" ref="ibanInput" :value="wedding.gift.iban" readonly spellcheck="false" /></dd></div><div v-if="wedding.gift.reference"><dt>Causale</dt><dd>{{ wedding.gift.reference }}</dd></div></dl><button type="button" class="button button-primary" @click="copyGiftIban">Copia IBAN</button><p role="status" aria-live="polite">{{ giftCopyStatus }}</p></div>
      <p v-else class="muted gift-placeholder">{{ wedding.gift.placeholder }}</p>
    </section>
  </main>
  <footer class="site-footer page-width"><a href="#" class="brand">{{ wedding.series.brand }}</a><p>{{ wedding.names }} · Una storia che continua.</p><a href="#" class="text-link">Torna all’inizio ↑</a></footer>
</template>
