<script setup lang="ts">
import { nextTick, reactive, ref } from 'vue'
import { wedding } from '../content/wedding'

const form = reactive({ firstName: '', lastName: '', email: '', attending: 'yes', guests: 1, guestNames: '', dietary: '' })
const status = ref('')
const ticketReleaseCount = ref(0)
const thankYouHeading = ref<HTMLElement>()
const ticketForm = ref<HTMLFormElement>()

async function resetTicket() {
  ticketReleaseCount.value = 0
  status.value = ''
  await nextTick()
  ticketForm.value?.querySelector('input')?.focus()
}
const fieldClass = 'mt-2 block min-h-12 w-full min-w-0 rounded-none border border-olive/50 bg-white/40 p-3 text-base font-normal focus-visible:outline-2 focus-visible:outline-offset-3 focus-visible:outline-olive'
const choiceClass = 'flex min-h-14 cursor-pointer items-center gap-2.5 border border-line p-3 has-checked:border-olive has-checked:bg-[#e9ecdf]'
const radioClass = 'size-4 shrink-0 accent-olive' 

// Replace this adapter with a Supabase call when a submission service is chosen.
function submitPresence() {
  if (ticketReleaseCount.value) return
  ticketReleaseCount.value += 1
  nextTick(() => thankYouHeading.value?.focus())
  if (!wedding.rsvpEmail) {
    status.value = 'Il modulo è in anteprima: la risposta non è stata inviata né salvata. Presto potrai confermare qui la tua presenza.'
    return
  }
  const attending = form.attending === 'yes'
  const body = [
    `Nome: ${form.firstName.trim()} ${form.lastName.trim()}`,
    `Email: ${form.email.trim()}`,
    `Presenza: ${attending ? 'Sì' : 'No'}`,
    ...(attending ? [`Persone totali: ${form.guests}`, `Altri ospiti: ${form.guestNames.trim()}`, `Esigenze alimentari: ${form.dietary.trim()}`] : []),
  ].join('\n')
  window.location.href = `mailto:${wedding.rsvpEmail}?subject=${encodeURIComponent('Conferma presenza matrimonio')}&body=${encodeURIComponent(body)}`
  status.value = 'Abbiamo richiesto l’apertura della tua app email. Invia il messaggio da lì per completare la conferma.'
}
</script>

<template>
  <form ref="ticketForm" class="ticket-scene min-w-0 [&_label]:min-w-0 [&_label]:text-[0.8rem] [&_label]:font-medium" @submit.prevent="submitPresence">
    <div class="ticket-stage">
      <div v-if="ticketReleaseCount" class="ticket-thanks" role="status">
        <h3 ref="thankYouHeading" tabindex="-1" class="font-serif text-4xl leading-tight sm:text-5xl">Grazie per la risposta</h3>
        <p class="mt-5 max-w-sm text-sm leading-7">{{ status }}</p>
        <button type="button" class="mt-6 min-h-11 border-b border-current text-xs" @click="resetTicket">{{ wedding.rsvpEmail ? 'Modifica la risposta' : 'Prova di nuovo' }}</button>
      </div>
      <div class="ticket-upper cinema-ticket p-4 text-ink sm:p-6 md:p-10" :class="{ 'is-falling': ticketReleaseCount > 0 }" :inert="ticketReleaseCount > 0" :aria-hidden="ticketReleaseCount > 0">

    <header class="ticket-header">
      <p class="ticket-kicker"> {{ wedding.names }}</p>
      <h3 aria-describedby="ticket-nominative-note">Il tuo biglietto<sup class="ml-1 text-sm" aria-hidden="true">*</sup></h3>
      <div class="ticket-meta"><span>La prima · {{ wedding.date || 'Data in arrivo' }}</span><span>Invito speciale</span></div>
    </header>
    <div class="ticket-body">
       <div class="grid gap-5 sm:grid-cols-2">
        <label>Nome <span aria-hidden="true">*</span><input :class="fieldClass" v-model="form.firstName" name="given-name" autocomplete="given-name" required maxlength="80" pattern=".*\S.*" /></label>
        <label>Cognome <span aria-hidden="true">*</span><input :class="fieldClass" v-model="form.lastName" name="family-name" autocomplete="family-name" required maxlength="80" pattern=".*\S.*" /></label>
        <label class="sm:col-span-2">Email <span aria-hidden="true">*</span><input :class="fieldClass" v-model="form.email" name="email" type="email" autocomplete="email" required maxlength="254" /></label>
      </div>
      <fieldset class="mt-6 min-w-0">
        <legend class="mb-3 text-sm">Ci sarai? <span aria-hidden="true">*</span></legend>
        <div class="grid gap-3 md:grid-cols-2 lg:grid-cols-1 xl:grid-cols-2">
          <label :class="choiceClass"><input :class="radioClass" v-model="form.attending" type="radio" name="attending" value="yes" required /> Ci sarò, contate su di me</label>
          <label :class="choiceClass"><input :class="radioClass" v-model="form.attending" type="radio" name="attending" value="no" /> Purtroppo non potrò esserci</label>
        </div>
      </fieldset>
      <div v-if="form.attending === 'yes'" class="mt-6 grid gap-5">
        <label>Persone totali, te compreso/a <span aria-hidden="true">*</span><input :class="fieldClass" v-model.number="form.guests" name="guests" type="number" min="1" max="20" required /><span class="mt-2 block text-xs font-normal text-ink/65">Includi solo le persone indicate nel tuo invito.</span></label>
        <label v-if="form.guests > 1">Nome e cognome degli altri ospiti <span aria-hidden="true">*</span><textarea :class="fieldClass" class="resize-y" v-model="form.guestNames" name="guest-names" rows="2" maxlength="1000" required /></label>
        <label>Allergie ed esigenze alimentari<textarea :class="fieldClass" class="resize-y" v-model="form.dietary" name="dietary" rows="2" maxlength="1000" placeholder="Indica il nome della persona e la sua esigenza" /></label>
      </div>
      <p class="mt-5 text-xs leading-6 text-ink/65">* Campi obbligatori. {{ wedding.rsvpEmail ? 'I dettagli saranno inseriti nel messaggio email; questo sito non li conserva.' : 'Questa anteprima non trasmette i dati.' }}</p>
      <button type="submit" class="mt-6 flex min-h-12 w-full items-center justify-between gap-4 bg-ink px-6 py-4 text-sm text-paper hover:bg-olive">{{ wedding.rsvpEmail ? 'Prepara la conferma via email' : 'Prova il modulo' }}<span aria-hidden="true">↗</span></button>
    </div>
      </div>
    </div>
    <footer :key="ticketReleaseCount" class="cinema-ticket ticket-stub" :class="{ 'is-released': ticketReleaseCount > 0 }"><div><span class="ticket-kicker">Conserva l’emozione</span><p>Una prima. Insieme.</p><span id="ticket-nominative-note" class="mt-3 block text-[0.65rem] leading-relaxed">* Il biglietto è nominativo e non cedibile.</span></div><span class="ticket-stamp" aria-hidden="true">J &amp; A<br>★</span></footer>
  </form>
</template>

<style scoped>
.ticket-stage { display: grid; overflow: clip; isolation: isolate; }
.ticket-upper, .ticket-thanks { grid-area: 1 / 1; min-width: 0; }
.ticket-upper { z-index: 1; transform-origin: bottom left; }
.ticket-upper.is-falling { animation: drop-ticket 1000ms 300ms cubic-bezier(.55, .05, .8, .4) both; }
.ticket-thanks { display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 2rem 1rem; text-align: center; color: #f5f2e9; animation: reveal-thanks 500ms 700ms ease both; }
.ticket-thanks h3:focus { outline: none; }
.ticket-scene > .ticket-stub { margin: 0; padding: 1.5rem; }
@keyframes drop-ticket {
  0% { transform: translateY(0) rotate(0); opacity: 1; }
  30% { transform: translateY(1rem) rotate(3deg); opacity: 1; }
  100% { transform: translateY(100%) rotate(14deg); opacity: 0; visibility: hidden; }
}
@keyframes reveal-thanks {
  from { opacity: 0; }
  to { opacity: 1; }
}
.ticket-stub { color: #343c32; transform-origin: top left; }
.ticket-stub.is-released {
  background: #eee7d4;
  transform: translateY(1rem) rotate(-1.5deg);
  box-shadow: 3px 8px 12px #0002;
  animation: release-ticket-stub 900ms cubic-bezier(.2, .7, .2, 1) both;
}
@keyframes release-ticket-stub {
  0% { transform: translateY(0) rotate(0) rotateX(0); box-shadow: 0 0 0 #0000; }
  35% { transform: translateY(.2rem) rotate(-.5deg) rotateX(-18deg); box-shadow: 2px 4px 8px #0001; }
  70% { transform: translateY(1.3rem) rotate(-2deg) rotateX(6deg); box-shadow: 4px 10px 16px #0003; }
  100% { transform: translateY(1rem) rotate(-1.5deg) rotateX(0); box-shadow: 3px 8px 12px #0002; }
}
@media (prefers-reduced-motion: reduce) {
  .ticket-stub.is-released, .ticket-thanks { animation: none; }
  .ticket-upper.is-falling { animation: none; visibility: hidden; }
}
</style>
