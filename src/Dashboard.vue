<script setup lang="ts">
import { computed, ref } from 'vue'
import { supabase } from './lib/supabase'
import SeatingPlanner from './components/SeatingPlanner.vue'

type Member = { guest_id: number, guest_name: string, attending: boolean | null }
type Family = {
  family_id: number, family_name: string, maximum_guests: number | null,
  allow_plus_one: boolean, plus_one_name: string | null, token: string, revoked_at: string | null,
  confirmed_count: number | null, notes: string | null, responded_at: string | null, members: Member[],
}
const password = ref('')
const unlocked = ref(false)
const activeTab = ref<'families' | 'tables'>('families')
const adminTabs = [{ id: 'families', label: 'Famiglie e risposte' }, { id: 'tables', label: 'Tavoli e posti' }] as const

function changeTab(event: KeyboardEvent) {
  const index = adminTabs.findIndex((tab) => tab.id === activeTab.value)
  let next = index
  if (event.key === 'ArrowRight') next = (index + 1) % adminTabs.length
  else if (event.key === 'ArrowLeft') next = (index + adminTabs.length - 1) % adminTabs.length
  else if (event.key === 'Home') next = 0
  else if (event.key === 'End') next = adminTabs.length - 1
  else return
  event.preventDefault()
  activeTab.value = adminTabs[next]!.id
  document.getElementById(`admin-tab-${activeTab.value}`)?.focus()
}
const busy = ref(false)
const error = ref('')
const message = ref('')
const families = ref<Family[]>([])
const familyName = ref('')
const memberNames = ref('')
const byHeadcount = ref(false)
const maximumGuests = ref(4)
const bonusOne = ref(false)
const existingFamily = ref('')
const newMember = ref('')
const search = ref('')
const newPassword = ref('')
const namedFamilies = computed(() => families.value.filter((family) => family.maximum_guests === null))
const displayedFamilies = computed(() => {
  const term = search.value.trim().toLocaleLowerCase('it')
  return families.value.filter((family) => `${family.family_name} ${family.members.map((member) => member.guest_name).join(' ')} ${family.plus_one_name ?? ''}`.toLocaleLowerCase('it').includes(term))
})
const invitedCount = computed(() => families.value.reduce((sum, family) => sum + family.members.length, 0))
const attendingCount = computed(() => families.value.reduce((sum, family) => sum + family.members.filter((member) => member.attending === true).length + (family.allow_plus_one && family.plus_one_name ? 1 : 0), 0))
const declinedCount = computed(() => families.value.reduce((sum, family) => sum + family.members.filter((member) => member.attending === false).length, 0))
const pendingCount = computed(() => families.value.reduce((sum, family) => sum + family.members.filter((member) => member.attending === null).length, 0))
const inputClass = 'mt-2 w-full min-w-0 border border-line bg-paper px-3 py-3 text-ink focus-visible:outline-2 focus-visible:outline-olive'
const buttonClass = 'min-h-11 border border-line px-4 text-sm disabled:opacity-50'

async function loadFamilies() {
  if (!supabase) { error.value = 'Il servizio non è configurato.'
  return }
  busy.value = true
  error.value = ''
  try {
    const { data, error: queryError } = await supabase.rpc('dashboard_family_invitations', { admin_password: password.value })
    if (queryError) throw queryError
    families.value = data as Family[]
    unlocked.value = true
  } catch { error.value = unlocked.value ? 'Impossibile caricare le risposte. Riprova.' : 'Accesso non riuscito. Controlla la password e riprova.' }
  finally { busy.value = false }
}
async function mutate(action: () => Promise<unknown>, success: string) {
  if (!supabase || busy.value) return
  busy.value = true
  error.value = ''
  message.value = ''
  try {
    await action()
    await loadFamilies()
    message.value = success
  }
  catch { error.value = 'Impossibile salvare. Controlla i dati e riprova.' }
  finally { busy.value = false }
}
async function createFamily() {
  await mutate(async () => {
    const { error: createError } = await supabase!.rpc('dashboard_create_family', {
      admin_password: password.value, family_name: familyName.value.trim(),
      member_names: byHeadcount.value ? [] : memberNames.value.split('\n').map((name) => name.trim()).filter(Boolean),
      maximum_guests: byHeadcount.value ? maximumGuests.value : null, bonus_one: bonusOne.value,
    })
    if (createError) throw createError
    familyName.value = ''
    memberNames.value = ''
    bonusOne.value = false
  }, 'Famiglia creata. Il suo unico link è nella tabella.')
}
async function addMember() {
  await mutate(async () => {
    const { error: addError } = await supabase!.rpc('dashboard_add_guest', {
      admin_password: password.value, family_name: '', guest_name: newMember.value.trim(), existing_family_id: Number(existingFamily.value),
    })
    if (addError) throw addError
    newMember.value = ''
  }, 'Membro aggiunto. Il link della famiglia resta lo stesso.')
}
async function setPlusOne(family: Family, event: Event) {
  const checkbox = event.target as HTMLInputElement
  const allowed = checkbox.checked
  checkbox.checked = family.allow_plus_one
  await mutate(async () => {
    const { error: updateError } = await supabase!.rpc('dashboard_set_family_plus_one', { admin_password: password.value, selected_family_id: family.family_id, allowed })
    if (updateError) throw updateError
  }, allowed ? 'Bonus +1 consentito.' : 'Bonus +1 rimosso.')
}
async function changePassword() {
  if (!supabase || busy.value) return
  busy.value = true
  error.value = ''
  message.value = ''
  try {
    const { error: changeError } = await supabase.rpc('dashboard_change_password', { admin_password: password.value, new_password: newPassword.value })
    if (changeError) throw changeError
    password.value = newPassword.value
    newPassword.value = ''
    message.value = 'Password aggiornata.'
  } catch { error.value = 'Impossibile aggiornare la password. Riprova.' }
  finally { busy.value = false }
}
function invitationUrl(token: string) {
  const url = new URL(import.meta.env.BASE_URL, window.location.origin)
  url.searchParams.set('invite', token)
  url.hash = 'presenza'
  return url.href
}
async function copyLink(token: string) {
  try {
    await navigator.clipboard.writeText(invitationUrl(token))
    message.value = 'Link della famiglia copiato.'
  }
  catch { message.value = 'Copia il link dal campo nella tabella.' }
}
function logout() {
  password.value = ''
  families.value = []
  unlocked.value = false
  activeTab.value = 'families'
  message.value = ''
  error.value = ''
}
</script>

<template>
  <main class="mx-auto px-5 py-12 sm:px-10 sm:py-16" :class="activeTab === 'tables' ? 'max-w-[100rem]' : 'max-w-7xl'">
    <header class="mb-10 flex flex-wrap items-start justify-between gap-5 border-b border-line pb-8">
      <div><p class="text-xs uppercase tracking-[0.2em] text-olive">Jacopo & Agnese · Area riservata</p><h1 class="mt-4 font-serif text-4xl sm:text-5xl">Gestione del matrimonio</h1></div>
      <button v-if="unlocked" :class="buttonClass" @click="logout">Esci</button>
    </header>
    <form v-if="!unlocked" class="max-w-sm border border-line bg-panel p-6" @submit.prevent="loadFamilies">
      <h2 class="font-serif text-2xl">Accedi</h2><label class="mt-5 block text-sm">Password<input v-model="password" :class="inputClass" type="password" autocomplete="current-password" required></label>
      <p v-if="error" role="alert" class="mt-4 text-sm">{{ error }}</p><button :disabled="busy" :class="buttonClass" class="mt-5 w-full bg-ink text-paper">{{ busy ? 'Accesso…' : 'Accedi' }}</button>
    </form>
    <template v-else>
      <div role="tablist" aria-label="Sezioni amministrazione" class="mb-8 flex gap-2 border-b border-line" @keydown="changeTab">
        <button v-for="tab in adminTabs" :id="`admin-tab-${tab.id}`" :key="tab.id" type="button" role="tab" :aria-selected="activeTab === tab.id" :aria-controls="`admin-panel-${tab.id}`" :tabindex="activeTab === tab.id ? 0 : -1" class="min-h-12 border-b-2 px-4 py-3 text-sm" :class="activeTab === tab.id ? 'border-olive bg-panel font-medium' : 'border-transparent hover:bg-panel'" @click="activeTab = tab.id">{{ tab.label }}</button>
      </div>
      <section id="admin-panel-families" :hidden="activeTab !== 'families'" role="tabpanel" aria-labelledby="admin-tab-families" tabindex="0">
      <div class="grid grid-cols-2 gap-3 sm:grid-cols-4"><div v-for="item in [{ label: 'Invitati previsti', count: invitedCount }, { label: 'Presenti', count: attendingCount }, { label: 'Assenti', count: declinedCount }, { label: 'In attesa', count: pendingCount }]" :key="item.label" class="border border-line bg-panel p-4"><p class="text-xs uppercase tracking-widest text-olive">{{ item.label }}</p><p class="mt-2 font-serif text-3xl">{{ item.count }}</p></div></div>
      <form class="mt-10 border border-line bg-panel p-5 sm:p-6" @submit.prevent="createFamily">
        <h2 class="font-serif text-2xl">Crea una famiglia</h2>
        <div class="mt-4 grid gap-4 sm:grid-cols-2">
          <label class="text-sm">Nome famiglia (o nome dell’unico invitato)<input v-model="familyName" :class="inputClass" maxlength="160" pattern=".*\S.*" required placeholder="Famiglia Murelli"></label>
          <label class="text-sm">Come risponde<select v-model="byHeadcount" :class="inputClass"><option :value="false">Per ciascun membro nominativo</option><option :value="true">Con il numero di persone</option></select></label>
          <label v-if="!byHeadcount" class="text-sm sm:col-span-2">Membri, uno per riga<textarea v-model="memberNames" :class="inputClass" rows="3" required placeholder="Chiara&#10;Francesco" /></label>
          <label v-else class="text-sm">Massimo persone (visibile solo in admin)<input v-model.number="maximumGuests" :class="inputClass" type="number" min="1" max="100" step="1" required><span class="mt-2 block text-xs">Il limite è verificato dal server. L’eventuale +1 è aggiuntivo.</span></label>
          <label class="flex min-h-11 items-center gap-2 text-sm"><input v-model="bonusOne" type="checkbox"> Consenti un bonus +1 per la famiglia</label>
        </div>
        <button :disabled="busy" :class="buttonClass" class="mt-5 bg-ink text-paper">Crea famiglia e link</button>
      </form>
      <form v-if="namedFamilies.length" class="mt-5 border border-line p-5" @submit.prevent="addMember">
        <h2 class="font-serif text-xl">Aggiungi un membro a una famiglia nominativa</h2><div class="mt-3 grid gap-4 sm:grid-cols-2"><label class="text-sm">Famiglia<select v-model="existingFamily" :class="inputClass" required><option value="" disabled>Scegli una famiglia</option><option v-for="family in namedFamilies" :key="family.family_id" :value="String(family.family_id)">{{ family.family_name }}</option></select></label><label class="text-sm">Nome membro<input v-model="newMember" :class="inputClass" maxlength="160" pattern=".*\S.*" required></label></div><button :disabled="busy" :class="buttonClass" class="mt-4">Aggiungi membro</button>
      </form>
      <form class="mt-6 flex flex-wrap items-end gap-3" @submit.prevent="changePassword"><label class="w-full text-sm sm:w-80">Nuova password (almeno 12 caratteri)<input v-model="newPassword" :class="inputClass" type="password" autocomplete="new-password" minlength="12" maxlength="72" required></label><button :disabled="busy" :class="buttonClass">Cambia password</button></form>
      <div class="mt-8 flex flex-wrap items-end justify-between gap-4"><h2 class="font-serif text-3xl">Un invito per famiglia</h2><label class="text-sm">Cerca<input v-model="search" :class="inputClass" type="search" placeholder="Nome o famiglia"></label></div>
      <p v-if="message" role="status" class="mt-4 text-sm text-olive">{{ message }}</p><p v-if="error" role="alert" class="mt-4 text-sm">{{ error }}</p>
      <div class="mt-4 overflow-x-auto border border-line bg-panel">
        <table class="w-full min-w-[800px] text-left text-sm"><thead class="border-b border-line text-xs uppercase tracking-wider text-olive"><tr><th class="p-4">Famiglia / membri</th><th class="p-4">Bonus +1</th><th class="p-4">Risposta</th><th class="p-4">Note</th><th class="p-4">Link della famiglia</th></tr></thead>
          <tbody><tr v-for="family in displayedFamilies" :key="family.family_id" class="border-b border-line align-top last:border-0">
            <td class="p-4"><strong>{{ family.family_name }}</strong><span v-if="family.maximum_guests !== null" class="mt-2 block text-xs">Per numero · Massimo privato: {{ family.maximum_guests }}</span><ul v-else class="mt-2 space-y-2"><li v-for="member in family.members" :key="member.guest_id"><span class="rounded px-2 py-1 text-xs" :class="member.attending === null ? 'bg-amber-100 text-amber-900' : member.attending ? 'bg-green-100 text-green-900' : 'bg-red-100 text-red-900'">{{ member.guest_name }} · {{ member.attending === null ? 'In attesa' : member.attending ? 'Presente' : 'Assente' }}</span></li></ul></td>
            <td class="p-4"><label class="flex min-h-11 items-center gap-2"><input type="checkbox" :checked="family.allow_plus_one" :disabled="busy" :aria-label="`Consenti +1 per ${family.family_name}`" @change="setPlusOne(family, $event)"> Consenti +1</label><span v-if="family.plus_one_name" class="mt-2 block">{{ family.plus_one_name }}</span></td>
            <td class="p-4"><span v-if="family.maximum_guests !== null">{{ family.confirmed_count === null ? 'In attesa' : `Confermati: ${family.confirmed_count}` }}</span><span v-else>{{ family.members.filter((member) => member.attending === true).length }} presenti · {{ family.members.filter((member) => member.attending === null).length }} in attesa</span><span v-if="family.responded_at" class="mt-2 block text-xs">{{ new Date(family.responded_at).toLocaleDateString('it-IT') }}</span></td>
            <td class="max-w-64 whitespace-pre-wrap break-words p-4">{{ family.notes || '—' }}</td>
            <td class="p-4"><span v-if="family.revoked_at">Revocato</span><div v-else class="flex gap-2"><input :value="invitationUrl(family.token)" readonly :aria-label="`Link per ${family.family_name}`" class="w-44 min-w-0 border border-line bg-paper p-2 text-xs" @focus="($event.target as HTMLInputElement).select()"><button :class="buttonClass" @click="copyLink(family.token)">Copia</button><a :href="invitationUrl(family.token)" :aria-label="`Apri il link per ${family.family_name} in una nuova scheda`" target="_blank" rel="noopener noreferrer" :class="buttonClass" class="inline-flex items-center whitespace-nowrap">Apri ↗</a></div></td>
          </tr></tbody>
        </table><p v-if="!displayedFamilies.length" class="p-5 text-sm">Nessuna famiglia trovata.</p>
      </div>
      </section>
      <section id="admin-panel-tables" :hidden="activeTab !== 'tables'" role="tabpanel" aria-labelledby="admin-tab-tables" tabindex="0">
        <SeatingPlanner :password="password" :revision="families" :active="activeTab === 'tables'" @refresh="loadFamilies" />
      </section>
    </template>
  </main>
</template>
