<script setup lang="ts">
import { computed, nextTick, onMounted, reactive, ref } from 'vue'
import { supabase } from '../lib/supabase'
import { wedding } from '../content/wedding'
import TicketBarcode from './TicketBarcode.vue'

const invitationParams = new URLSearchParams(window.location.search)
// Also accept invitation parameters appended to the ticket anchor.
const fragmentParams = new URLSearchParams(window.location.hash.split('?')[1]?.split('#')[0] ?? '')
const form = reactive({ count: null as number | null, notes: '', bringCompanion: false, companionName: '' })
const byHeadcount = ref(false)
const allowPlusOne = ref(false)
let nextPersonId = 0
const addedPeople = ref([{ id: nextPersonId++, name: '', attending: '' }])
const loadedInvitation = ref(false)
const responseToken = ref('')
const familyName = ref('')
const members = ref<{ guest_id: number, guest_name: string, attending: string }[]>([])
const familyTitle = computed(() => /^famiglia\b/i.test(familyName.value) ? familyName.value : `Famiglia ${familyName.value}`)
const familySummary = computed(() => {
  const names = new Intl.ListFormat('it', { style: 'long', type: 'conjunction' }).format(members.value.map((member) => member.guest_name))
  return `${familyTitle.value}${names ? `: ${names}` : ''}${allowPlusOne.value ? ' +1' : ''}`
})
const anyoneAttending = computed(() => byHeadcount.value ? Number(form.count) > 0 : members.value.some((member) => member.attending === 'yes') || addedPeople.value.some((person) => person.attending === 'yes'))
const invitationToken = invitationParams.get('invite') ?? fragmentParams.get('invite') ?? ''
const hasInvitationToken = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(invitationToken)
const invitationState = ref<'loading' | 'ready'>(hasInvitationToken ? 'loading' : 'ready')
const formError = ref('')
const isSubmitting = ref(false)

onMounted(async () => {
  if (!hasInvitationToken) return
  if (!supabase) {
    invitationState.value = 'ready'
    formError.value = 'Il servizio di conferma non è disponibile. Contatta gli sposi.'
    return
  }
  try {
    const { data, error } = await supabase.rpc('get_invitation', { invitation_token: invitationToken })
    if (error) throw error
    if (!data) {
      invitationState.value = 'ready'
      return
    }
    loadedInvitation.value = true
    responseToken.value = invitationToken
    addedPeople.value = []
    byHeadcount.value = data.by_headcount === true
    form.count = data.confirmed_count ?? null
    allowPlusOne.value = data.allow_plus_one === true
    familyName.value = data.family_name ?? ''
    members.value = (data.members ?? []).map((member: { guest_id: number, guest_name: string, attending: boolean | null }) => ({
      guest_id: member.guest_id, guest_name: member.guest_name,
      attending: member.attending === null ? '' : member.attending ? 'yes' : 'no',
    }))
    form.bringCompanion = Boolean(data.plus_one_name)
    form.companionName = data.plus_one_name ?? ''
    form.notes = data.notes ?? ''
    invitationState.value = 'ready'
  } catch {
    invitationState.value = 'ready'
    formError.value = 'Impossibile caricare l’invito. Riprova più tardi.'
  }
})
const status = ref('')
const ticketReleaseCount = ref(0)
const thankYouHeading = ref<HTMLElement>()
const ticketForm = ref<HTMLFormElement>()
const cinemaSeat = ref<{ hall: number, seat: string, code: string }>()

async function resetTicket() {
  ticketReleaseCount.value = 0
  status.value = ''
  await nextTick()
  ticketForm.value?.querySelector('input')?.focus()
}
const fieldClass = 'block min-h-11 w-full min-w-0 rounded-none border border-olive/50 bg-white/40 px-3 py-2 text-base font-normal placeholder:text-ink/65 focus-visible:outline-2 focus-visible:outline-offset-3 focus-visible:outline-olive'
const choiceClass = 'flex min-h-11 cursor-pointer items-center gap-2 border border-line px-3 py-2 has-checked:border-olive has-checked:bg-[#e9ecdf]'
const radioClass = 'size-4 shrink-0 accent-olive' 

async function submitPresence() {
  if (ticketReleaseCount.value || isSubmitting.value || invitationState.value !== 'ready') return
  if (!supabase) {
    formError.value = 'Il servizio di conferma non è disponibile. Contatta gli sposi.'
    return
  }
  formError.value = ''
  isSubmitting.value = true
  try {
    const { data, error } = await supabase.rpc('submit_open_response', {
      invitation_token: responseToken.value || null,
      family_name: familyName.value.trim() || addedPeople.value[0]?.name.trim() || '',
      added_people: addedPeople.value.map((person) => ({ guest_name: person.name.trim(), attending: person.attending === 'yes' })),
      confirmed_count: byHeadcount.value ? form.count : null,
      guest_notes: form.notes.trim(),
      companion_name: allowPlusOne.value && anyoneAttending.value && form.bringCompanion ? form.companionName.trim() : null,
      member_responses: byHeadcount.value ? [] : members.value.map((member) => ({ guest_id: member.guest_id, attending: member.attending === 'yes' })),
    })
    if (error) throw error
    if (!data) {
      invitationState.value = 'ready'
      formError.value = 'Questo link di invito non è più valido. Contatta gli sposi.'
      return
    }
    familyName.value = data.family_name
    responseToken.value = data.token
    loadedInvitation.value = true
    members.value = data.members.map((member: { guest_id: number, guest_name: string, attending: boolean }) => ({
      ...member, attending: member.attending ? 'yes' : 'no',
    }))
    addedPeople.value = []
  } catch (cause) {
    const requestError = cause as { code?: string }
    formError.value = byHeadcount.value && requestError.code === '22023'
      ? 'Controlla il numero di persone. Contatta gli sposi se hai bisogno di aiuto.'
      : 'Non siamo riusciti a salvare la risposta. Controlla la connessione e riprova.'
    return
  } finally {
    isSubmitting.value = false
  }
  if (anyoneAttending.value && !cinemaSeat.value) {
    cinemaSeat.value = {
      hall: Math.floor(Math.random() * 4) + 1,
      seat: `${Math.floor(Math.random() * 20) + 1}${'ABCDEFGH'[Math.floor(Math.random() * 8)]}`,
      code: String(Math.floor(Math.random() * 1000000)).padStart(6, '0'),
    }
  }
  status.value = 'La tua risposta è stata salvata. Puoi modificarla da questa pagina.'
  ticketReleaseCount.value += 1
  nextTick(() => thankYouHeading.value?.focus())
}
</script>

<template>
  <section v-if="invitationState !== 'ready'" class="ticket-scene" aria-busy="true" aria-labelledby="unavailable-ticket-title">
    <div class="cinema-ticket ticket-upper text-ink">
      <header class="ticket-header">
        <p class="ticket-kicker">{{ wedding.names }}</p>
        <div class="ticket-meta mt-3"><span>La prima · {{ wedding.date || 'Data in arrivo' }}</span><span>Proiezione unica</span></div>
      </header>
      <div class="px-3 py-8 text-center sm:py-12" role="status">
          <h3 id="unavailable-ticket-title" class="font-serif text-3xl">{{ 'Il tuo biglietto' }}</h3>
          <p class="mt-5 text-sm leading-7">{{ invitationState === 'loading' ? 'Caricamento invito…' : formError }}</p>
      </div>
    </div>
    <footer class="cinema-ticket ticket-stub">
      <div class="ticket-stub-copy"><span class="ticket-kicker">Conserva l’emozione</span><p>Una prima. Insieme.</p></div>
      <span class="ticket-stamp" aria-hidden="true">J &amp; A<br>★</span>
    </footer>
  </section>
  <form v-else ref="ticketForm" class="ticket-scene min-w-0 [&_label]:min-w-0 [&_label]:text-[0.8rem] [&_label]:font-medium" @submit.prevent="submitPresence">
    <div class="ticket-stage">
      <div v-if="ticketReleaseCount" class="ticket-thanks" role="status">
        <h3 ref="thankYouHeading" tabindex="-1" class="font-serif text-4xl leading-tight sm:text-5xl">Grazie per la risposta</h3>
        <p class="mt-5 max-w-sm text-sm leading-7">{{ status }}</p>
        <button type="button" class="mt-6 min-h-11 border-b border-current text-xs" @click="resetTicket">Modifica la risposta</button>
      </div>
      <div class="ticket-upper cinema-ticket text-ink" :class="{ 'is-falling': ticketReleaseCount > 0 }" :inert="ticketReleaseCount > 0" :aria-hidden="ticketReleaseCount > 0">

    <header class="ticket-header">
      <p class="ticket-kicker"> {{ wedding.names }}</p>
      <h3 aria-describedby="ticket-nominative-note">Il tuo biglietto<sup class="ml-1 text-sm" aria-hidden="true">*</sup></h3>
      <div class="ticket-meta"><span>La prima · {{ wedding.date || 'Data in arrivo' }}</span><span>Invito speciale</span></div>
    </header>
    <div class="ticket-body">
      <p v-if="loadedInvitation" class="font-serif text-lg leading-7">{{ familySummary }}</p>
      <label v-if="byHeadcount" class="block">Confermiamo per:
        <input v-model.number="form.count" :class="fieldClass" class="mt-2" type="number" name="confirmed-count" min="0" step="1" required>
        <span class="mt-2 block text-xs leading-5">Indica il numero di persone presenti. Se non potrete esserci, inserisci 0.</span>
      </label>
      <template v-else>
        <fieldset v-for="member in members" :key="member.guest_id" class="min-w-0">
          <legend class="mb-2 text-sm">{{ member.guest_name }} *</legend>
          <div class="grid grid-cols-2 gap-2">
            <label :class="choiceClass"><input v-model="member.attending" :class="radioClass" type="radio" :name="`member-${member.guest_id}`" value="yes" required> Ci sarà</label>
            <label :class="choiceClass"><input v-model="member.attending" :class="radioClass" type="radio" :name="`member-${member.guest_id}`" value="no" required> Non ci sarà</label>
          </div>
        </fieldset>
      </template>
      <template v-if="!byHeadcount">
        <fieldset v-for="(person, index) in addedPeople" :key="person.id" :aria-label="person.name.trim() || 'Nome e cognome'" class="min-w-0">
          <label><span class="sr-only">Nome e cognome *</span><input v-model="person.name" :class="fieldClass" class="mb-2" placeholder="Nome e cognome *" :name="`person-name-${person.id}`" maxlength="160" pattern=".*\S.*" required></label>
          <div class="grid grid-cols-2 gap-2">
            <label :class="choiceClass"><input v-model="person.attending" :class="radioClass" type="radio" :name="`person-${person.id}`" value="yes" required> Ci sarà</label>
            <label :class="choiceClass"><input v-model="person.attending" :class="radioClass" type="radio" :name="`person-${person.id}`" value="no" required> Non ci sarà</label>
          </div>
          <button v-if="loadedInvitation || addedPeople.length > 1" type="button" class="min-h-11 text-sm underline" @click="addedPeople.splice(index, 1)">Rimuovi persona</button>
        </fieldset>
        <button type="button" class="min-h-11 border border-olive px-3 py-2 text-sm" @click="addedPeople.push({ id: nextPersonId++, name: '', attending: '' })">Aggiungi una persona</button>
      </template>
      <div v-if="allowPlusOne && anyoneAttending" class="grid min-w-0 gap-2">
        <label :class="choiceClass"><input v-model="form.bringCompanion" :class="radioClass" type="checkbox"> Aggiungiamo un accompagnatore (+1)</label>
        <label v-if="form.bringCompanion"><span class="mb-1 block">Nome e cognome dell’accompagnatore *</span><input v-model="form.companionName" :class="fieldClass" name="companion" placeholder="Nome e cognome *" maxlength="160" pattern=".*\S.*" required></label>
      </div>
      <div class="ticket-notes min-w-0">
        <label><span class="sr-only">Note (facoltative)</span><textarea :class="fieldClass" class="resize-y" v-model="form.notes" name="notes" rows="2" maxlength="1000" placeholder="Note (facoltative)" /></label>
      </div>
      <p class="ticket-privacy text-[11px] leading-4 text-ink/65">* Campi obbligatori. La risposta sarà salvata per organizzare il matrimonio.</p>
      <p v-if="formError" role="alert" class="text-sm leading-5 text-[#8a2929]">{{ formError }}</p>
      <button type="submit" :disabled="isSubmitting" class="ticket-submit flex min-h-11 w-full items-center justify-between gap-3 bg-ink px-4 py-2 text-sm text-paper hover:bg-olive">{{ isSubmitting ? 'Invio in corso…' : 'Conferma la risposta' }}<span aria-hidden="true">↗</span></button>
    </div>
      </div>
    </div>
    <footer :key="ticketReleaseCount" class="cinema-ticket ticket-stub" :class="{ 'is-released': ticketReleaseCount > 0 }">
      <div class="ticket-stub-copy">
        <span class="ticket-kicker">Conserva l’emozione</span>
        <p>Una prima. Insieme.</p>
      </div>
      <dl v-if="ticketReleaseCount && anyoneAttending && cinemaSeat" class="ticket-seat" aria-label="Il tuo posto al cinema (dettagli di scena)">
        <div><dt>Sala</dt><dd>{{ cinemaSeat.hall }}</dd></div>
        <div><dt>Posto</dt><dd>{{ cinemaSeat.seat }}</dd></div>
      </dl>
      <TicketBarcode v-if="ticketReleaseCount && anyoneAttending && cinemaSeat" :code="cinemaSeat.code" />
      <span class="ticket-stamp" aria-hidden="true">J &amp; A<br>★</span>
      <span id="ticket-nominative-note" class="ticket-nominative-note block text-[0.65rem] leading-tight">* Indica una risposta per ogni persona del gruppo.</span>
    </footer>
  </form>
</template>

<style scoped>
.ticket-scene { width: 100%; max-width: 38rem; margin-inline: auto; scroll-margin-top: 0; }
.ticket-header { padding: .6rem; }
.ticket-header h3 { margin: .3rem 0 .5rem; font-size: clamp(1.5rem, 4vw, 2rem); }
.ticket-meta { padding-top: .4rem; gap: .25rem .75rem; }
.ticket-body { display: grid; gap: .65rem; padding-top: .75rem; }
.ticket-stage { display: grid; overflow: clip; isolation: isolate; }
.ticket-upper, .ticket-thanks { grid-area: 1 / 1; min-width: 0; }
.ticket-upper { z-index: 1; padding: clamp(.75rem, 2vh, 1.25rem); transform-origin: bottom left; }
.ticket-upper.is-falling { animation: drop-ticket 1000ms 300ms cubic-bezier(.55, .05, .8, .4) both; }
.ticket-thanks { display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 2rem 1rem; text-align: center; color: #f5f2e9; animation: reveal-thanks 500ms 700ms ease both; }
.ticket-thanks h3:focus { outline: none; }
.ticket-scene > .ticket-stub { display: grid; grid-template-columns: minmax(0, 1fr) auto; margin: 0; padding: .6rem .75rem; gap: .25rem .5rem; }
.ticket-stub:has(.ticket-seat) { grid-template-columns: minmax(0, 1fr) auto auto; }
.ticket-nominative-note { grid-column: 1 / -1; }
.ticket-stub p { margin-top: .15rem; font-size: 1rem; }
.ticket-stamp { padding: .3rem; font-size: .65rem; }
.ticket-stub-copy { min-width: 0; flex: 1; }
.ticket-seat { display: grid; flex-shrink: 0; gap: .4rem; font-family: 'Courier New', monospace; font-size: .75rem; font-weight: 700; line-height: 1.3; }
.ticket-seat > div { display: flex; gap: .4rem; }
@media (max-width: 639px), (max-height: 600px) {
  .ticket-stub :deep(.ticket-barcode) { display: none; }
}
@media (min-width: 640px) and (min-height: 601px) {
  .ticket-stub:has(.ticket-seat) { grid-template-columns: minmax(0, 1fr) auto auto auto; }
}
@media (max-width: 359px) {
  .ticket-stub-copy .ticket-kicker { font-size: .5rem; letter-spacing: .1em; }
  .ticket-stub-copy p { font-size: .875rem; }
  .ticket-header h3 { font-size: 1.2rem; }
  .ticket-meta > span:last-child { display: none; }
}
@media (max-height: 650px) and (max-width: 599px) {
  .ticket-upper { padding: .65rem; }
  .ticket-body { gap: .5rem; padding-top: .5rem; }
  .ticket-notes textarea { height: 56px; min-height: 44px; }
}
@media (max-height: 600px) and (min-width: 480px) {
  .ticket-scene > .ticket-stub { padding-block: .4rem; }
  .ticket-stage { position: relative; }
  .ticket-upper.is-falling { position: absolute; inset: 0; }
  .ticket-thanks { padding: .75rem; }
  .ticket-thanks h3 { font-size: 1.5rem; }
  .ticket-thanks p { margin-top: .5rem; font-size: .75rem; line-height: 1.4; }
  .ticket-thanks button { margin-top: .25rem; }
  .ticket-upper { padding: .65rem; }
  .ticket-header { padding: .4rem; }
  .ticket-header h3 { margin: .2rem 0 .3rem; font-size: 1.5rem; }
  .ticket-body { grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: .5rem; padding-top: .5rem; }
  .ticket-notes textarea { height: 44px; min-height: 44px; }
  .ticket-privacy { align-self: center; }
  .ticket-submit { grid-column: 1 / -1; }
}
@media (max-height: 350px) and (min-width: 480px) {
  .ticket-header .ticket-kicker { display: none; }
  .ticket-meta { display: none; }
  .ticket-header h3 { font-size: 1.25rem; }
  .ticket-scene > .ticket-stub { padding-block: .25rem; }
}
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
