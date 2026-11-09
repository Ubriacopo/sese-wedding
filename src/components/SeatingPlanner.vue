<script setup lang="ts">
import {computed, nextTick, onMounted, onUnmounted, ref, watch} from 'vue'
import {supabase} from '../lib/supabase'

type DiningTable = { id: number, name: string, capacity: number, x: number, y: number, archived: boolean }
type Person = {
  key: string,
  name: string,
  family_name: string,
  attending: boolean | null,
  companion: boolean,
  table_id: number | null,
  seat_number: number | null
}
const props = defineProps<{ password: string, revision: unknown[], active: boolean }>()
const emit = defineEmits<{ refresh: [] }>()
const tables = ref<DiningTable[]>([])
const people = ref<Person[]>([])
const busy = ref(false)
const loaded = ref(false)
const error = ref('')
const message = ref('')
const search = ref('')
const statusFilter = ref('all')
const unassignedOnly = ref(false)
const selectedPersonKey = ref('')
const assignmentHeading = ref<HTMLElement>()
const selectedTableId = ref<number | null>(null)
const editingTable = ref(false)
const tableName = ref('')
const capacity = ref(8)
const targetTable = ref('')
const targetSeat = ref('')
const zoom = ref('fit')
const editorWidth = ref(0)
const effectiveZoom = computed(() => zoom.value === 'fit' ? Math.max(1, editorWidth.value / 1200) : Number(zoom.value))
const floorScroll = ref<HTMLElement>()
const cameraPanning = ref(false)
let cameraDrag: { pointerId: number, x: number, y: number, scrollLeft: number, scrollTop: number } | undefined
const planner = ref<HTMLElement>()
const editor = ref<HTMLElement>()
const peoplePanel = ref<HTMLElement>()
const tablePanel = ref<HTMLElement>()
const panelPositions = ref<Record<'people' | 'table', { x: number, y: number } | null>>({people: null, table: null})
const panelOpen = ref({people: true, table: false})
let panelDrag: {
  name: 'people' | 'table',
  pointerId: number,
  startX: number,
  startY: number,
  x: number,
  y: number
} | undefined
let editorResizeObserver: ResizeObserver | undefined

function panelElement(name: 'people' | 'table') {
  return name === 'people' ? peoplePanel.value : tablePanel.value
}

function constrainPanel(name: 'people' | 'table', x: number, y: number) {
  const area = editor.value
  const panel = panelElement(name)
  if (!area || !panel) return {x, y}
  return {
    x: Math.max(0, Math.min(x, Math.max(0, area.clientWidth - panel.offsetWidth))),
    y: Math.max(0, Math.min(y, Math.max(0, area.clientHeight - panel.offsetHeight)))
  }
}

function panelStyle(name: 'people' | 'table') {
  const position = panelPositions.value[name]
  return position ? {left: `${position.x}px`, top: `${position.y}px`, right: 'auto', bottom: 'auto'} : undefined
}

function startPanelDrag(event: PointerEvent, name: 'people' | 'table') {
  if (event.button !== 0 || personDrag.value || drag) return
  const panel = panelElement(name)
  const area = editor.value
  if (!panel || !area) return
  const bounds = area.getBoundingClientRect()
  const panelBounds = panel.getBoundingClientRect()
  panelDrag = {
    name,
    pointerId: event.pointerId,
    startX: event.clientX,
    startY: event.clientY,
    x: panelBounds.left - bounds.left,
    y: panelBounds.top - bounds.top
  }
  ;(event.currentTarget as HTMLElement).setPointerCapture(event.pointerId)
}

function movePanel(event: PointerEvent) {
  if (!panelDrag || panelDrag.pointerId !== event.pointerId) return
  panelPositions.value[panelDrag.name] = constrainPanel(panelDrag.name, panelDrag.x + event.clientX - panelDrag.startX, panelDrag.y + event.clientY - panelDrag.startY)
}

function endPanelDrag(event: PointerEvent) {
  if (panelDrag?.pointerId === event.pointerId) panelDrag = undefined
}

function movePanelWithKeyboard(event: KeyboardEvent, name: 'people' | 'table') {
  const directions: Record<string, [number, number]> = {
    ArrowLeft: [-20, 0],
    ArrowRight: [20, 0],
    ArrowUp: [0, -20],
    ArrowDown: [0, 20]
  }
  const direction = directions[event.key]
  const panel = panelElement(name)
  const area = editor.value
  if (!direction || !panel || !area) return
  event.preventDefault()
  const bounds = area.getBoundingClientRect()
  const panelBounds = panel.getBoundingClientRect()
  panelPositions.value[name] = constrainPanel(name, panelBounds.left - bounds.left + direction[0], panelBounds.top - bounds.top + direction[1])
}

function clampPanels() {
  for (const name of ['people', 'table'] as const) {
    const position = panelPositions.value[name]
    if (position) panelPositions.value[name] = constrainPanel(name, position.x, position.y)
  }
}

function startCameraPan(event: PointerEvent) {
  if (event.button !== 1 || !floorScroll.value || personDrag.value || drag || panelDrag) return
  event.preventDefault()
  cameraDrag = {
    pointerId: event.pointerId,
    x: event.clientX,
    y: event.clientY,
    scrollLeft: floorScroll.value.scrollLeft,
    scrollTop: floorScroll.value.scrollTop
  }
  cameraPanning.value = true
  floorScroll.value.setPointerCapture(event.pointerId)
}

function moveCamera(event: PointerEvent) {
  if (!cameraDrag || cameraDrag.pointerId !== event.pointerId || !floorScroll.value) return
  event.preventDefault()
  floorScroll.value.scrollLeft = cameraDrag.scrollLeft - (event.clientX - cameraDrag.x)
  floorScroll.value.scrollTop = cameraDrag.scrollTop - (event.clientY - cameraDrag.y)
}

function endCameraPan(event: PointerEvent) {
  if (cameraDrag?.pointerId !== event.pointerId) return
  cameraDrag = undefined
  cameraPanning.value = false
}

const fullscreenButton = ref<HTMLButtonElement>()
const fullscreen = ref(false)
let previousBodyOverflow = ''
const personDrag = ref<{
  person: Person,
  pointerId: number,
  originX: number,
  originY: number,
  x: number,
  y: number,
  active: boolean
}>()
const dropTarget = ref<{ table: DiningTable, seat: number | null }>()
let dragFrame = 0
let suppressSeatClickUntil = 0
const dropHint = computed(() => {
  if (!personDrag.value?.active) return ''
  if (!dropTarget.value) return 'Trascina su un tavolo o su un posto libero.'
  return dropTarget.value.seat === null ? 'Tavolo pieno o posto occupato.' : `${dropTarget.value.table.name} · Posto ${dropTarget.value.seat}`
})
const activeTables = computed(() => tables.value.filter((table) => !table.archived))
const selectedTable = computed(() => tables.value.find((table) => table.id === selectedTableId.value))
const selectedPerson = computed(() => people.value.find((person) => person.key === selectedPersonKey.value))
const destination = computed(() => activeTables.value.find((table) => table.id === Number(targetTable.value)))
const seating = computed(() => new Map(people.value.filter((person) => person.table_id !== null).map((person) => [`${person.table_id}:${person.seat_number}`, person])))
const unassignedCount = computed(() => people.value.filter((person) => !activeTables.value.some((table) => table.id === person.table_id)).length)
const visiblePeople = computed(() => {
  const term = search.value.trim().toLocaleLowerCase('it')
  return people.value.filter((person) => `${person.name} ${person.family_name}`.toLocaleLowerCase('it').includes(term)
      && (statusFilter.value === 'all' || statusFilter.value === status(person))
      && (!unassignedOnly.value || !activeTables.value.some((table) => table.id === person.table_id)))
})
const inputClass = 'mt-1 min-h-11 w-full min-w-0 border border-line bg-paper px-3 py-2 text-sm'
const buttonClass = 'min-h-11 border border-line px-3 py-2 text-sm disabled:opacity-50'
const statusLabels = {confirmed: 'Confermato', pending: 'In attesa', declined: 'Assente'}

function status(person: Person) {
  return person.attending === null ? 'pending' : person.attending ? 'confirmed' : 'declined'
}

function initials(person: Person) {
  return person.name.trim().split(/\s+/).map((part) => part[0]).slice(0, 2).join('').toLocaleUpperCase('it')
}

function occupant(tableId: number, seat: number) {
  return seating.value.get(`${tableId}:${seat}`)
}

function occupancy(tableId: number) {
  return people.value.filter((person) => person.table_id === tableId).length
}

function placement(person: Person) {
  const table = activeTables.value.find((table) => table.id === person.table_id)
  return table ? `${table.name} · Posto ${person.seat_number}` : 'Da assegnare'
}

function seatStyle(seat: number, count: number) {
  const angle = (seat - 1) / count * Math.PI * 2 - Math.PI / 2
  return {left: `${150 + Math.cos(angle) * 106}px`, top: `${174 + Math.sin(angle) * 106}px`}
}

function selectTable(table?: DiningTable) {
  editingTable.value = false
  selectedTableId.value = table?.id ?? null
  tableName.value = table?.name ?? ''
  capacity.value = table?.capacity ?? 8
}

function editTable(table?: DiningTable) {
  selectTable(table)
  editingTable.value = true
  panelOpen.value.table = true
}

function selectPerson(person: Person) {
  if (performance.now() < suppressSeatClickUntil) return
  selectedPersonKey.value = person.key
  panelOpen.value.table = true
  const currentTable = activeTables.value.find((table) => table.id === person.table_id)
  targetTable.value = currentTable ? String(currentTable.id) : ''
  targetSeat.value = currentTable ? String(person.seat_number) : ''
  nextTick(() => assignmentHeading.value?.focus())
}

function selectSeat(table: DiningTable, seat: number) {
  if (performance.now() < suppressSeatClickUntil) return
  selectTable(table)
  const person = occupant(table.id, seat)
  if (person) selectPerson(person)
  targetTable.value = String(table.id)
  targetSeat.value = String(seat)
}

async function loadPlan() {
  if (!supabase) throw new Error('Servizio non disponibile')
  const {data, error: queryError} = await supabase.rpc('dashboard_seating_plan', {admin_password: props.password})
  if (queryError) throw queryError
  tables.value = data.tables
  people.value = data.people
  loaded.value = true
  if (!people.value.some((person) => person.key === selectedPersonKey.value)) selectedPersonKey.value = ''
}

function showError(cause: unknown) {
  const databaseError = cause as { code?: string, message?: string }
  error.value = databaseError.code === '22023' ? databaseError.message ?? 'Controlla i dati.'
      : databaseError.code === '23514' ? 'Controlla la capienza (1–20 posti) e la posizione del tavolo.'
          : 'Impossibile salvare o caricare la disposizione. Riprova con Aggiorna.'
}

async function refresh() {
  if (busy.value) return
  busy.value = true
  error.value = ''
  try {
    await loadPlan()
  } catch (cause) {
    showError(cause)
  } finally {
    busy.value = false
  }
}

async function mutate(action: () => Promise<unknown>, success: string) {
  if (busy.value || !supabase) return
  busy.value = true
  error.value = ''
  message.value = ''
  try {
    await action()
    await loadPlan()
    message.value = success
  } catch (cause) {
    showError(cause)
    try {
      await loadPlan()
    } catch { /* Keep the last loaded plan visible for retry. */
    }
  } finally {
    busy.value = false
  }
}

async function saveTable() {
  await mutate(async () => {
    const {data, error: saveError} = await supabase!.rpc('dashboard_save_table', {
      admin_password: props.password,
      table_name: tableName.value.trim(),
      seat_capacity: capacity.value,
      selected_table_id: selectedTableId.value,
    })
    if (saveError) throw saveError
    selectedTableId.value = data
    editingTable.value = false
  }, 'Tavolo salvato.')
}

async function archiveTable(table: DiningTable, archived: boolean) {
  await mutate(async () => {
    const {error: archiveError} = await supabase!.rpc('dashboard_archive_table', {
      admin_password: props.password,
      selected_table_id: table.id,
      is_archived: archived
    })
    if (archiveError) throw archiveError
    if (archived && selectedTableId.value === table.id) selectTable()
  }, archived ? 'Tavolo rimosso.' : 'Tavolo ripristinato.')
}

async function assignPerson(personKey: string, tableId: number | null, seat: number | null) {
  await mutate(async () => {
    const {error: seatError} = await supabase!.rpc('dashboard_assign_seat', {
      admin_password: props.password, person_key: personKey,
      selected_table_id: tableId, selected_seat: seat,
    })
    if (seatError) throw seatError
    selectedPersonKey.value = personKey
    targetTable.value = tableId === null ? '' : String(tableId)
    targetSeat.value = seat === null ? '' : String(seat)
  }, tableId === null ? 'Posto liberato.' : 'Posto assegnato.')
}

async function assign(unassign = false) {
  if (!selectedPerson.value) return
  await assignPerson(selectedPersonKey.value, unassign ? null : Number(targetTable.value), unassign ? null : Number(targetSeat.value))
}

function findDropTarget(x: number, y: number) {
  const element = document.elementFromPoint(x, y)
  const tableElement = element?.closest<HTMLElement>('[data-drop-table]')
  const table = activeTables.value.find((item) => item.id === Number(tableElement?.dataset.dropTable))
  if (!table || !personDrag.value) {
    dropTarget.value = undefined
    return
  }
  const seatElement = element?.closest<HTMLElement>('[data-drop-seat]')
  let seat: number | null = seatElement ? Number(seatElement.dataset.dropSeat) : null
  if (!seatElement) {
    for (let candidate = 1; candidate <= table.capacity; candidate++) {
      if (!occupant(table.id, candidate) || occupant(table.id, candidate)?.key === personDrag.value.person.key) {
        seat = candidate
        break
      }
    }
  }
  if (seat !== null && occupant(table.id, seat) && occupant(table.id, seat)?.key !== personDrag.value.person.key) seat = null
  dropTarget.value = {table, seat}
}

function scrollWhileDragging() {
  const current = personDrag.value
  if (!current?.active) return
  const floor = floorScroll.value
  const bounds = floor?.getBoundingClientRect()
  if (floor && bounds && current.x >= bounds.left && current.x <= bounds.right && current.y >= bounds.top && current.y <= bounds.bottom) {
    floor.scrollBy(current.x > bounds.right - 40 ? 10 : current.x < bounds.left + 40 ? -10 : 0,
        current.y > bounds.bottom - 40 ? 10 : current.y < bounds.top + 40 ? -10 : 0)
  }
  const verticalScroll = current.y < 60 ? -12 : current.y > window.innerHeight - 60 ? 12 : 0
  if (verticalScroll) {
    if (fullscreen.value) planner.value?.scrollBy(0, verticalScroll)
    else window.scrollBy(0, verticalScroll)
  }
  findDropTarget(current.x, current.y)
  dragFrame = requestAnimationFrame(scrollWhileDragging)
}

function startPersonDrag(event: PointerEvent, person?: Person) {
  if (!person || busy.value || drag || personDrag.value || event.button !== 0) return
  personDrag.value = {
    person,
    pointerId: event.pointerId,
    originX: event.clientX,
    originY: event.clientY,
    x: event.clientX,
    y: event.clientY,
    active: false
  }
  const handle = event.currentTarget as HTMLElement
  handle.setPointerCapture(event.pointerId)
}

function movePersonDrag(event: PointerEvent) {
  const current = personDrag.value
  if (!current || current.pointerId !== event.pointerId) return
  current.x = event.clientX
  current.y = event.clientY
  if (!current.active && Math.hypot(current.x - current.originX, current.y - current.originY) >= 6) {
    current.active = true
    message.value = ''
    error.value = ''
    dragFrame = requestAnimationFrame(scrollWhileDragging)
  }
  if (current.active) {
    event.preventDefault()
    findDropTarget(current.x, current.y)
  }
}

function cancelPersonDrag() {
  if (personDrag.value?.active) suppressSeatClickUntil = performance.now() + 400
  personDrag.value = undefined
  dropTarget.value = undefined
  cancelAnimationFrame(dragFrame)
}

async function endPersonDrag(event: PointerEvent) {
  const current = personDrag.value
  if (!current || current.pointerId !== event.pointerId) return
  if (!current.active) {
    cancelPersonDrag()
    return
  }
  findDropTarget(event.clientX, event.clientY)
  const target = dropTarget.value
  cancelPersonDrag()
  if (!target) {
    message.value = 'Spostamento annullato. Rilascia su un tavolo o su un posto libero.'
    return
  }
  if (target.seat === null) {
    error.value = 'Il posto è occupato o il tavolo è pieno. Scegli un posto libero.'
    return
  }
  await assignPerson(current.person.key, target.table.id, target.seat)
}

function dragKeydown(event: KeyboardEvent) {
  if (event.key === 'Escape' && personDrag.value) {
    event.preventDefault()
    cancelPersonDrag()
  } else if (event.key === 'Escape' && fullscreen.value) {
    event.preventDefault()
    setFullscreen(false)
  } else if (event.key === 'Tab' && fullscreen.value && planner.value) {
    const controls = [...planner.value.querySelectorAll<HTMLElement>('a[href], button:not(:disabled), input:not(:disabled), select:not(:disabled), textarea:not(:disabled), summary, [tabindex]:not([tabindex="-1"])')]
        .filter((control) => control.getClientRects().length > 0)
    const first = controls[0]
    const last = controls[controls.length - 1]
    if (first && last && event.shiftKey && (document.activeElement === first || !planner.value.contains(document.activeElement))) {
      event.preventDefault()
      last.focus()
    } else if (first && last && !event.shiftKey && (document.activeElement === last || !planner.value.contains(document.activeElement))) {
      event.preventDefault()
      first.focus()
    }
  }
}

function setFullscreen(open: boolean) {
  if (open === fullscreen.value) return
  if (open) {
    previousBodyOverflow = document.body.style.overflow
    document.body.style.overflow = 'hidden'
  } else {
    document.body.style.overflow = previousBodyOverflow
  }
  fullscreen.value = open
  nextTick(() => fullscreenButton.value?.focus())
}

async function moveTable(table: DiningTable, x: number, y: number) {
  await mutate(async () => {
    const {error: moveError} = await supabase!.rpc('dashboard_move_table', {
      admin_password: props.password, selected_table_id: table.id,
      position_x: Math.max(0, Math.min(900, Math.round(x))), position_y: Math.max(0, Math.min(600, Math.round(y))),
    })
    if (moveError) throw moveError
  }, 'Posizione salvata.')
}

let drag: { table: DiningTable, clientX: number, clientY: number, x: number, y: number } | undefined

function startDrag(event: PointerEvent, table: DiningTable) {
  if (busy.value || personDrag.value || event.button !== 0) return
  selectTable(table)
  drag = {table, clientX: event.clientX, clientY: event.clientY, x: table.x, y: table.y}
  const handle = event.currentTarget as HTMLElement
  handle.setPointerCapture(event.pointerId)
}

function dragTable(event: PointerEvent) {
  if (!drag) return
  drag.table.x = Math.max(0, Math.min(900, Math.round(drag.x + (event.clientX - drag.clientX) / effectiveZoom.value)))
  drag.table.y = Math.max(0, Math.min(600, Math.round(drag.y + (event.clientY - drag.clientY) / effectiveZoom.value)))
}

async function endDrag(cancelled = false) {
  if (!drag) return
  const current = drag
  drag = undefined
  if (cancelled) {
    current.table.x = current.x;
    current.table.y = current.y;
    return
  }
  if (current.table.x !== current.x || current.table.y !== current.y) await moveTable(current.table, current.table.x, current.table.y)
}

onMounted(() => {
  editorResizeObserver = new ResizeObserver(() => {
    editorWidth.value = editor.value?.clientWidth ?? 0
    clampPanels()
  })
  if (editor.value) editorResizeObserver.observe(editor.value)
  if (peoplePanel.value) editorResizeObserver.observe(peoplePanel.value)
  if (tablePanel.value) editorResizeObserver.observe(tablePanel.value)
  if (props.active) refresh()
  window.addEventListener('keydown', dragKeydown)
})
onUnmounted(() => {
  editorResizeObserver?.disconnect()
  cancelPersonDrag()
  if (fullscreen.value) document.body.style.overflow = previousBodyOverflow
  window.removeEventListener('keydown', dragKeydown)
})
watch(() => props.revision, () => {
  if (props.active) refresh()
})
watch(() => props.active, (active) => {
  if (active) refresh()
  else {
    cancelPersonDrag()
    endDrag(true)
    if (fullscreen.value) setFullscreen(false)
  }
})
</script>

<template>
  <section ref="planner" class="seating-planner min-w-0" :class="{ 'is-fullscreen': fullscreen }"
           :role="fullscreen ? 'dialog' : undefined" :aria-modal="fullscreen ? 'true' : undefined"
           aria-labelledby="seating-title">
    <div class="flex flex-wrap items-end justify-between gap-4">
      <div><p class="text-xs uppercase tracking-[0.2em] text-olive">La disposizione in sala</p>
        <h2 id="seating-title" class="mt-3 font-serif text-3xl sm:text-4xl">Tavoli e posti</h2>
      </div>
      <div class="flex flex-wrap gap-2">
        <button ref="fullscreenButton" type="button" :class="buttonClass" :aria-pressed="fullscreen"
                @click="setFullscreen(!fullscreen)">{{ fullscreen ? 'Esci da schermo intero' : 'Schermo intero' }}
        </button>
        <button type="button" :class="buttonClass" :disabled="busy" @click="refresh(); emit('refresh')">
          {{ busy ? 'Aggiornamento…' : 'Aggiorna RSVP e pianta' }}
        </button>
      </div>
    </div>
    <ul class="mt-5 flex flex-wrap gap-3 text-xs" aria-label="Legenda risposte">
      <li v-for="(label, key) in statusLabels" :key="key" class="status-chip" :class="key">{{ label }}</li>
    </ul>
    <p v-if="message" role="status" class="mt-4 text-sm text-olive">{{ message }}</p>
    <p v-if="error" role="alert" class="mt-4 text-sm text-red-700">{{ error }}</p>
    <p v-if="personDrag?.active" role="status" class="mt-3 text-sm">{{ dropHint }}</p>
    <div class="planner-workspace mt-6 min-w-0" :aria-busy="busy">
      <div class="planner-content min-w-0">
        <div class="flex flex-wrap items-center justify-between gap-3 border border-line bg-panel p-3 text-sm">
          <span>{{ activeTables.length }} tavoli · {{ unassignedCount }} persone da assegnare</span><label>Zoom <select
            v-model="zoom" class="min-h-11 border border-line bg-paper px-2">
          <option value="fit">Adatta alla larghezza</option>
          <option value="0.5">50%</option>
          <option value="0.75">75%</option>
          <option value="1">100%</option>
        </select></label></div>
        <div ref="editor" class="editor-surface">
          <div ref="floorScroll" class="floor-scroll" :class="{ 'is-panning': cameraPanning }" tabindex="0"
               aria-label="Pianta dei tavoli, scorribile in entrambe le direzioni" @pointerdown="startCameraPan"
               @pointermove="moveCamera" @pointerup="endCameraPan" @pointercancel="endCameraPan"
               @lostpointercapture="endCameraPan" @auxclick.middle.prevent>
            <div :style="{ width: `${1200 * effectiveZoom}px`, height: `${900 * effectiveZoom}px` }">
              <div class="floor-plan" :style="{ transform: `scale(${effectiveZoom})` }">
                <p v-if="!activeTables.length && loaded" class="p-8 text-sm text-olive">La sala è ancora vuota. Crea il
                  primo tavolo dal pannello.</p>
                <article v-for="table in activeTables" :key="table.id" class="dining-table" :data-drop-table="table.id"
                         :class="{ selected: selectedTableId === table.id, 'drop-table': dropTarget && dropTarget.table.id === table.id }"
                         :style="{ left: `${table.x}px`, top: `${table.y}px` }" :aria-label="table.name">
                  <button type="button" class="table-handle" :disabled="busy"
                          :aria-label="`Seleziona o trascina ${table.name}`" @click="selectTable(table)"
                          @pointerdown="startDrag($event, table)" @pointermove="dragTable" @pointerup="endDrag()"
                          @pointercancel="endDrag(true)">{{ table.name }} <span aria-hidden="true">⠿</span></button>
                  <button type="button" class="table-edit" :disabled="busy" :aria-label="`Modifica ${table.name}`" :title="`Modifica ${table.name}`" @click.stop="editTable(table)">✎</button>
                  <div class="table-center"><span class="text-xs uppercase tracking-widest">Tavolo</span><strong
                      class="mt-2 block max-w-28 break-words font-serif text-lg leading-tight">{{ table.name }}</strong><span
                      class="mt-2 block text-xs">{{ occupancy(table.id) }} / {{ table.capacity }} posti</span></div>
                  <button v-for="seat in table.capacity" :key="seat" type="button" class="seat" :data-drop-seat="seat"
                          :class="[occupant(table.id, seat) ? status(occupant(table.id, seat)!) : 'empty', { chosen: targetTable === String(table.id) && targetSeat === String(seat), 'drop-seat': dropTarget && dropTarget.table.id === table.id && dropTarget.seat === seat }]"
                          :style="seatStyle(seat, table.capacity)" :disabled="busy"
                          :aria-label="`${table.name}, posto ${seat}: ${occupant(table.id, seat) ? `${occupant(table.id, seat)!.name}, ${occupant(table.id, seat)!.family_name}, ${statusLabels[status(occupant(table.id, seat)!)]}` : 'libero'}`"
                          @pointerdown="startPersonDrag($event, occupant(table.id, seat))" @pointermove="movePersonDrag"
                          @pointerup="endPersonDrag" @pointercancel="cancelPersonDrag"
                          @lostpointercapture="cancelPersonDrag" @click="selectSeat(table, seat)">
                    <span>{{ occupant(table.id, seat) ? initials(occupant(table.id, seat)!) : seat }}</span>
                    <span v-if="occupant(table.id, seat)" class="seat-name" :class="{ 'seat-name-below': Math.sin((seat - 1) / table.capacity * Math.PI * 2 - Math.PI / 2) >= 0 }" aria-hidden="true">{{ occupant(table.id, seat)!.name }}</span>
                    <span class="seat-tooltip" aria-hidden="true">
                    <template v-if="occupant(table.id, seat)">
                      <strong>{{ occupant(table.id, seat)!.name }}{{
                          occupant(table.id, seat)!.companion ? ' (+1)' : ''
                        }}</strong>
                      <span>{{
                          occupant(table.id, seat)!.family_name
                        }} · {{ statusLabels[status(occupant(table.id, seat)!)] }}</span>
                    </template>
                    <strong v-else>Posto libero</strong>
                    <span>{{ table.name }} · Posto {{ seat }}</span>
                  </span>
                  </button>
                </article>
              </div>
            </div>
          </div>
          <aside ref="peoplePanel" class="floating-panel people-panel" :style="panelStyle('people')"
                 aria-label="Persone">
            <div class="panel-bar">
              <button type="button" class="panel-handle"
                      aria-label="Sposta pannello persone con il puntatore o le frecce"
                      @pointerdown="startPanelDrag($event, 'people')" @pointermove="movePanel" @pointerup="endPanelDrag"
                      @pointercancel="endPanelDrag" @lostpointercapture="endPanelDrag"
                      @keydown="movePanelWithKeyboard($event, 'people')">⠿ Persone
              </button>
              <button type="button" class="panel-toggle" :aria-expanded="panelOpen.people"
                      aria-controls="people-panel-content" @click="panelOpen.people = !panelOpen.people">
                {{ panelOpen.people ? '−' : '+' }}<span class="sr-only"> {{ panelOpen.people ? 'Chiudi' : 'Apri' }} pannello persone</span>
              </button>
            </div>
            <div v-show="panelOpen.people" id="people-panel-content" class="panel-body p-3">
              <div class="flex flex-wrap items-end gap-2"><label class="min-w-0 flex-1 text-sm">Cerca una persona<input
                  v-model="search" :class="inputClass" type="search" placeholder="Nome o famiglia"></label><label
                  class="text-sm">Risposta<select v-model="statusFilter" :class="inputClass">
                <option value="all">Tutte</option>
                <option v-for="(label, key) in statusLabels" :key="key" :value="key">{{ label }}</option>
              </select></label><label class="flex min-h-11 items-center gap-2 text-sm"><input v-model="unassignedOnly"
                                                                                              type="checkbox"> Solo da
                assegnare</label></div>
              <ul class="mt-2 grid max-h-80 gap-1 overflow-y-auto p-1">
                <li v-for="person in visiblePeople" :key="person.key">
                  <button type="button" class="person-card"
                          :class="[status(person), { chosen: selectedPersonKey === person.key }]" :disabled="busy"
                          :aria-pressed="selectedPersonKey === person.key"
                          :aria-label="`${person.name}, ${person.family_name}, ${statusLabels[status(person)]}, ${placement(person)}. Seleziona per assegnare o trascina su un tavolo`"
                          @click="selectPerson(person)" @pointerdown="startPersonDrag($event, person)"
                          @pointermove="movePersonDrag" @pointerup="endPersonDrag" @pointercancel="cancelPersonDrag"
                          @lostpointercapture="cancelPersonDrag"><span class="font-medium">{{
                      person.name
                    }}{{ person.companion ? ' (+1)' : '' }}</span><span class="text-xs">{{ person.family_name }} · {{ placement(person) }}</span>
                  </button>
                </li>
              </ul>
              <p v-if="loaded && !visiblePeople.length" class="mt-4 text-sm">Nessuna persona trovata.</p>
            </div>
          </aside>
          <aside ref="tablePanel" class="floating-panel table-panel" :style="panelStyle('table')"
                 aria-label="Modifica tavoli e assegnazioni">
            <div class="panel-bar">
              <button type="button" class="panel-handle"
                      aria-label="Sposta pannello tavoli con il puntatore o le frecce"
                      @pointerdown="startPanelDrag($event, 'table')" @pointermove="movePanel" @pointerup="endPanelDrag"
                      @pointercancel="endPanelDrag" @lostpointercapture="endPanelDrag"
                      @keydown="movePanelWithKeyboard($event, 'table')">⠿ Tavoli e assegnazioni
              </button>
              <button type="button" class="panel-toggle" aria-label="Nuovo tavolo" title="Nuovo tavolo" @click="editTable()">+</button>
              <button v-if="selectedTable && !selectedTable.archived" type="button" class="panel-toggle" :disabled="busy" :aria-label="`Rimuovi ${selectedTable.name}`" :title="`Rimuovi ${selectedTable.name}`" @click="archiveTable(selectedTable, true)">🗑</button>
              <button type="button" class="panel-toggle" :aria-expanded="panelOpen.table"
                      aria-controls="table-panel-content" @click="panelOpen.table = !panelOpen.table">
                {{ panelOpen.table ? '−' : '+' }}<span class="sr-only"> {{ panelOpen.table ? 'Chiudi' : 'Apri' }} pannello tavoli</span>
              </button>
            </div>
            <div v-show="panelOpen.table" id="table-panel-content" class="panel-body space-y-4 p-4">
              <form v-if="editingTable" class="border border-line bg-panel p-4" @submit.prevent="saveTable">
                <div class="flex items-center justify-between gap-2"><h3 class="font-serif text-xl">
                  {{ selectedTable ? 'Modifica tavolo' : 'Nuovo tavolo' }}</h3>

                </div>
                <label class="mt-3 block text-sm">Nome tavolo<input v-model="tableName" :class="inputClass"
                                                                    maxlength="80" pattern=".*\S.*" required></label>
                <label class="mt-3 block text-sm">Numero di posti<input v-model.number="capacity" :class="inputClass"
                                                                        type="number" min="1" max="20" step="1"
                                                                        required></label>
                <button :disabled="busy || !loaded" :class="buttonClass" class="mt-4 w-full bg-ink text-paper">
                  {{ selectedTable ? 'Salva tavolo' : 'Crea tavolo' }}
                </button>

              </form>
              <form v-if="selectedPerson" class="selected-person border border-line bg-panel p-3" @submit.prevent="assign()">
                <h3 ref="assignmentHeading" tabindex="-1" class="break-words font-serif text-lg">{{
                    selectedPerson.name
                  }}</h3>
                <p class="mt-2 text-xs">{{ selectedPerson.family_name }} · {{ placement(selectedPerson) }}</p>
                <div class="mt-2 grid grid-cols-2 gap-2"><label class="block text-sm">Tavolo<select v-model="targetTable" :class="inputClass" required
                                                                @change="targetSeat = ''">
                  <option value="" disabled>Scegli un tavolo</option>
                  <option v-for="table in activeTables" :key="table.id" :value="String(table.id)">{{
                      table.name
                    }}
                  </option>
                </select></label>
                <label class="block text-sm">Posto<select v-model="targetSeat" :class="inputClass" required>
                  <option value="" disabled>Scegli un posto</option>
                  <option v-for="seat in destination?.capacity ?? 0" :key="seat" :value="String(seat)"
                          :disabled="!!occupant(destination!.id, seat) && occupant(destination!.id, seat)?.key !== selectedPerson.key">
                    {{
                      seat
                    }}{{
                      occupant(destination!.id, seat) ? ` · ${occupant(destination!.id, seat)!.name}` : ' · Libero'
                    }}
                  </option>
                </select></label></div>
                <button :disabled="busy || !targetTable || !targetSeat" :class="buttonClass"
                        class="mt-2 w-full bg-ink text-paper">Assegna posto
                </button>
                <button v-if="selectedPerson.table_id !== null" type="button" :disabled="busy" :class="buttonClass"
                        class="mt-2 w-full" @click="assign(true)">Rimuovi assegnazione
                </button>
              </form>
            </div>
          </aside>
        </div>
      </div>
    </div>

    <Teleport to="body">
      <div v-if="personDrag?.active" class="person-ghost" :class="status(personDrag.person)"
           :style="{ left: `${personDrag.x + 16}px`, top: `${personDrag.y + 16}px` }" aria-hidden="true">
        {{ personDrag.person.name }}<span class="block text-xs">{{ dropHint }}</span></div>
    </Teleport>
  </section>
</template>

<style scoped>
.seating-planner.is-fullscreen {
  position: fixed;
  inset: 0;
  z-index: 90;
  overflow: auto;
  padding: clamp(1rem, 2vw, 2rem);
  background: var(--color-paper);
  color: var(--color-ink);
  display: flex;
  flex-direction: column;
}

.is-fullscreen .planner-workspace, .is-fullscreen .planner-content { display: flex; flex: 1; min-height: 0; flex-direction: column; }
.is-fullscreen .editor-surface { flex: 1; min-height: 0; }
.is-fullscreen .floor-scroll { height: 100%; min-height: 0; }

.editor-surface {
  position: relative;
  min-width: 0;
}

.floating-panel {
  position: absolute;
  z-index: 10;
  top: .75rem;
  width: min(19rem, calc(100% - 1.5rem));
  max-height: calc(100% - .75rem);
  display: flex;
  flex-direction: column;
  border: 1px solid var(--color-line);
  background: var(--color-panel);
  box-shadow: 0 6px 24px #0003;
}

.people-panel {
  left: .75rem;
}

.table-panel {
  right: .75rem;
}

.panel-bar {
  display: flex;
  flex-shrink: 0;
  border-bottom: 1px solid var(--color-line);
  background: var(--color-panel);
}

.panel-handle {
  flex: 1;
  min-width: 0;
  min-height: 44px;
  padding: .5rem .75rem;
  text-align: left;
  font-weight: 600;
  font-size: .8rem;
  cursor: grab;
  touch-action: none;
  user-select: none;
}

.panel-handle:active {
  cursor: grabbing;
}

.panel-toggle {
  width: 44px;
  min-height: 44px;
  border-left: 1px solid var(--color-line);
  font-size: 1.25rem;
}

.panel-body {
  min-height: 0;
  overflow-y: auto;
}

@media (max-width: 639px) {
  .floating-panel {
    width: min(17rem, calc(100% - 1.5rem));
  }

  .table-panel {
    top: auto;
    bottom: .75rem;
  }
}

.floor-scroll {
  height: min(800px, 75vh);
  min-height: 420px;
  overflow: auto;
  border: 1px solid var(--color-line);
  border-top: 0;
  background: var(--color-paper);
}

.floor-scroll.is-panning, .floor-scroll.is-panning * {
  cursor: grabbing;
  user-select: none;
}

.is-fullscreen .editor-surface {
  position: relative;
  min-width: 0;
}

.floating-panel {
  position: absolute;
  z-index: 10;
  top: .75rem;
  width: min(19rem, calc(100% - 1.5rem));
  max-height: calc(100% - .75rem);
  display: flex;
  flex-direction: column;
  border: 1px solid var(--color-line);
  background: var(--color-panel);
  box-shadow: 0 6px 24px #0003;
}

.people-panel {
  left: .75rem;
}

.table-panel {
  right: .75rem;
}

.panel-bar {
  display: flex;
  flex-shrink: 0;
  border-bottom: 1px solid var(--color-line);
  background: var(--color-panel);
}

.panel-handle {
  flex: 1;
  min-width: 0;
  min-height: 44px;
  padding: .5rem .75rem;
  text-align: left;
  font-weight: 600;
  font-size: .8rem;
  cursor: grab;
  touch-action: none;
  user-select: none;
}

.panel-handle:active {
  cursor: grabbing;
}

.panel-toggle {
  width: 44px;
  min-height: 44px;
  border-left: 1px solid var(--color-line);
  font-size: 1.25rem;
}

.panel-body {
  min-height: 0;
  overflow-y: auto;
}

@media (max-width: 639px) {
  .floating-panel {
    width: min(17rem, calc(100% - 1.5rem));
  }

  .table-panel {
    top: 4rem;
  }
}

.floor-plan {
  position: relative;
  width: 1200px;
  height: 900px;
  transform-origin: top left;
  background-image: radial-gradient(var(--color-line) 1px, transparent 1px);
  background-size: 20px 20px;
}

.dining-table {
  position: absolute;
  width: 300px;
  height: 300px;
  border: 1px dashed transparent;
  border-radius: 12px;
}

.dining-table:has(.seat:hover), .dining-table:has(.seat:focus-visible) {
  z-index: 5;
}

.dining-table.selected {
  border-color: var(--color-olive);
  background: color-mix(in srgb, var(--color-panel) 45%, transparent);
}

.table-handle {
  position: absolute;
  z-index: 1;
  top: 0;
  left: 30px;
  width: 196px;
  min-height: 44px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: .5rem;
  padding: 0 12px;
  border: 1px solid var(--color-line);
  background: var(--color-panel);
  cursor: grab;
  touch-action: none;
  font-size: 12px;
  overflow-wrap: anywhere;
}

.table-handle:active {
  cursor: grabbing;
}
.table-edit { position: absolute; z-index: 1; top: 0; right: 30px; width: 44px; min-height: 44px; border: 1px solid var(--color-line); background: var(--color-panel); font-size: 1.1rem; }

.table-center {
  position: absolute;
  top: 110px;
  left: 86px;
  width: 128px;
  height: 128px;
  border: 2px solid var(--color-olive);
  border-radius: 50%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  background: var(--color-panel);
}

.seat {
  touch-action: none;
  user-select: none;
  position: absolute;
  width: 32px;
  height: 32px;
  border: 1px solid;
  border-radius: 50%;
  transform: translate(-50%, -50%);
  font-size: 11px;
  font-weight: 600;
}

.seat-name { position: absolute; left: 50%; bottom: calc(100% + 2px); transform: translateX(-50%); max-width: 7rem; color: var(--color-ink); font-size: .65rem; font-weight: 600; line-height: 1.2; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; text-shadow: 0 0 3px var(--color-paper), 0 0 5px var(--color-paper); pointer-events: none; }
.seat-name-below { top: calc(100% + 2px); bottom: auto; }
.seat-tooltip {
  visibility: hidden;
  position: absolute;
  z-index: 10;
  left: 50%;
  bottom: calc(100% + .5rem);
  width: max-content;
  max-width: 14rem;
  min-width: 9rem;
  transform: translateX(-50%);
  padding: .6rem .75rem;
  border: 1px solid var(--color-olive);
  background: var(--color-paper);
  color: var(--color-ink);
  box-shadow: 0 4px 14px #0003;
  font-size: .75rem;
  font-weight: 400;
  line-height: 1.45;
  text-align: left;
  white-space: normal;
  overflow-wrap: anywhere;
  pointer-events: none;
}

.seat-tooltip strong, .seat-tooltip span {
  display: block;
}

.seat-tooltip strong {
  font-weight: 700;
}

.seat-tooltip span {
  margin-top: .2rem;
}

.seat:hover .seat-tooltip, .seat:focus-visible .seat-tooltip { visibility: visible; }

.empty {
  background: var(--color-paper);
  color: var(--color-olive);
  border-color: var(--color-line);
}

.confirmed {
  background: #e3f1e6;
  color: #205437;
  border-color: #7eaa8a;
}

.pending {
  background: #fff1cf;
  color: #71500d;
  border-color: #c8a755;
}

.declined {
  background: #f8e1df;
  color: #872e32;
  border-color: #c78b8b;
}

.status-chip {
  padding: .4rem .7rem;
  border-width: 1px;
  border-style: solid;
  border-radius: 999px;
}

.person-card {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: .2rem;
  width: 100%;
  min-height: 0;
  padding: .5rem .65rem;
  border-width: 1px;
  border-style: solid;
  text-align: left;
  overflow-wrap: anywhere;
  cursor: grab;
  touch-action: none;
  user-select: none;
}

.person-card:active {
  cursor: grabbing;
}

.chosen {
  outline: 3px solid var(--color-ink);
  outline-offset: 3px;
}

.person-ghost {
  position: fixed;
  z-index: 100;
  pointer-events: none;
  max-width: 240px;
  padding: .6rem .8rem;
  border: 1px solid;
  border-radius: 6px;
  box-shadow: 0 6px 20px #0003;
}

.drop-table {
  background: color-mix(in srgb, var(--color-olive) 15%, transparent);
}

.drop-seat {
  outline: 3px solid var(--color-olive);
  outline-offset: 3px;
}

</style>
