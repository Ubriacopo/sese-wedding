<script setup lang="ts">
import { reactive, ref } from 'vue'
import { wedding } from '../content/wedding'

const form = reactive({ firstName: '', lastName: '', email: '', attending: 'yes', guests: 1, guestNames: '', dietary: '', message: '' })
const status = ref('')
const fieldClass = 'mt-2 block min-h-12 w-full min-w-0 rounded-none border border-olive/50 bg-white/40 p-3 text-base font-normal focus-visible:outline-2 focus-visible:outline-offset-3 focus-visible:outline-olive'
const choiceClass = 'flex min-h-14 cursor-pointer items-center gap-2.5 border border-line p-3 has-checked:border-olive has-checked:bg-[#e9ecdf]'
const radioClass = 'size-4 shrink-0 accent-olive' 

// Replace this adapter with a Supabase call when a submission service is chosen.
function submitPresence() {
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
    `Messaggio: ${form.message.trim()}`,
  ].join('\n')
  window.location.href = `mailto:${wedding.rsvpEmail}?subject=${encodeURIComponent('Conferma presenza matrimonio')}&body=${encodeURIComponent(body)}`
  status.value = 'Abbiamo richiesto l’apertura della tua app email. Invia il messaggio da lì per completare la conferma.'
}
</script>

<template>
  <form class="min-w-0 border border-line bg-paper p-4 text-ink shadow-[6px_6px_0_#ffffff12] sm:p-6 md:p-10 [&_label]:min-w-0 [&_label]:text-[0.8rem] [&_label]:font-medium" @submit.prevent="submitPresence">
    <p class="mb-7 text-xs leading-6 text-ink/75">{{ wedding.rsvpEmail ? 'Compila i dettagli: potrai inviarli dalla tua app email.' : 'Un piccolo assaggio del modulo. Le conferme non sono ancora aperte e i dati non vengono salvati.' }}</p>
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
      <label>Persone totali, te compreso/a <span aria-hidden="true">*</span><input v-model.number="form.guests" name="guests" type="number" min="1" max="20" required /><span class="mt-2 block text-xs font-normal text-ink/65">Includi solo le persone indicate nel tuo invito.</span></label>
      <label v-if="form.guests > 1">Nome e cognome degli altri ospiti <span aria-hidden="true">*</span><textarea :class="fieldClass" class="resize-y" v-model="form.guestNames" name="guest-names" rows="2" maxlength="1000" required /></label>
      <label>Allergie ed esigenze alimentari<textarea :class="fieldClass" class="resize-y" v-model="form.dietary" name="dietary" rows="2" maxlength="1000" placeholder="Indica il nome della persona e la sua esigenza" /></label>
    </div>
    <label class="mt-6 block">Un messaggio per noi <span class="font-normal text-ink/60">(facoltativo)</span><textarea :class="fieldClass" class="resize-y" v-model="form.message" name="message" rows="3" maxlength="2000" /></label>
    <p class="mt-5 text-xs leading-6 text-ink/65">* Campi obbligatori. {{ wedding.rsvpEmail ? 'I dettagli saranno inseriti nel messaggio email; questo sito non li conserva.' : 'Questa anteprima non trasmette i dati.' }}</p>
    <button type="submit" class="mt-6 flex min-h-12 w-full items-center justify-between gap-4 bg-ink px-6 py-4 text-sm text-paper hover:bg-olive">{{ wedding.rsvpEmail ? 'Prepara la conferma via email' : 'Prova il modulo' }}<span aria-hidden="true">↗</span></button>
    <p role="status" aria-live="polite" class="mt-4 text-sm leading-6">{{ status }}</p>
  </form>
</template>
