<script setup lang="ts">
import { nextTick, reactive, ref } from 'vue'
import { wedding } from '../content/wedding'

const invitationParams = new URLSearchParams(window.location.search)
const fragmentParams = new URLSearchParams(window.location.hash.split('?')[1]?.split('#')[0] ?? '')
const invitationName = [
  invitationParams.get('name') ?? fragmentParams.get('name'),
  invitationParams.get('surname') ?? fragmentParams.get('surname'),
].filter(Boolean).join(' ').replace(/\s+/g, ' ').trim().slice(0, 160)
const form = reactive({ name: invitationName, attending: 'yes', notes: '' })
const status = ref('')
const submitted = ref(false)
const statusHeading = ref<HTMLElement>()
const presenceForm = ref<HTMLFormElement>()
async function editResponse() {
  submitted.value = false
  status.value = ''
  await nextTick()
  presenceForm.value?.querySelector('input')?.focus()
}
function submitPresence() {
  if (submitted.value) return
  submitted.value = true
  nextTick(() => statusHeading.value?.focus())
  if (!wedding.rsvpEmail) {
    status.value = 'Il modulo è in anteprima: la risposta non è stata inviata né salvata. Presto potrai confermare qui la tua presenza.'
    return
  }
  const body = [
    `Nome: ${form.name.trim()}`,
    `Presenza: ${form.attending === 'yes' ? 'Sì' : 'No'}`,
    `Note: ${form.notes.trim()}`,
  ].join('\n')
  window.location.href = `mailto:${wedding.rsvpEmail}?subject=${encodeURIComponent('Conferma presenza matrimonio')}&body=${encodeURIComponent(body)}`
  status.value = 'Abbiamo richiesto l’apertura della tua app email. Invia il messaggio da lì per completare la conferma.'
}
</script>

<template>
  <form id="presenza" ref="presenceForm" class="presence-form" @submit.prevent="submitPresence">
    <div v-if="submitted" class="response-status" role="status">
      <p class="eyebrow">La tua partecipazione</p><h3 ref="statusHeading" tabindex="-1">{{ wedding.rsvpEmail ? 'Completa la conferma via email' : 'Hai provato il modulo' }}</h3>
      <p>{{ status }}</p><button type="button" class="text-link" @click="editResponse">{{ wedding.rsvpEmail ? 'Modifica la risposta' : 'Prova di nuovo' }}</button>
    </div>
    <template v-else>
      <header><p class="eyebrow">Un invito per te</p><h3>Prendi parte alla storia.</h3><p>{{ wedding.date || 'Data in arrivo' }} · {{ wedding.names }}</p></header>
      <label for="guest-name">Il tuo nome <span aria-hidden="true">*</span></label>
      <input id="guest-name" v-model="form.name" name="name" autocomplete="name" placeholder="Nome e cognome" required maxlength="160" pattern=".*\S.*" />
      <fieldset><legend>Ci sarai? <span aria-hidden="true">*</span></legend><div class="attendance-options"><label><input v-model="form.attending" type="radio" name="attending" value="yes" required /> Ci sarò</label><label><input v-model="form.attending" type="radio" name="attending" value="no" /> Non ci sarò</label></div></fieldset>
      <label for="guest-notes">Note <span class="muted">(facoltative)</span></label><textarea id="guest-notes" v-model="form.notes" name="notes" rows="3" maxlength="1000" placeholder="Allergie, esigenze alimentari o un messaggio per noi" />
      <p class="form-privacy">* Campi obbligatori. {{ wedding.rsvpEmail ? 'Conferma inviando l’email. Il sito non conserva i dati.' : 'Questa anteprima non trasmette né salva i dati.' }}</p>
      <button type="submit" class="button button-primary">{{ wedding.rsvpEmail ? 'Prepara la conferma via email' : 'Prova il modulo' }} <span aria-hidden="true">↗</span></button>
    </template>
  </form>
</template>
