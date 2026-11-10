<script setup lang="ts">
import {computed, onMounted, ref} from 'vue'
import {supabase} from '../lib/supabase'
import {wedding} from '../content/wedding'

// Vite discovers the folder at development/build time; shuffle once per page load.
const photos = Object.values(import.meta.glob<string>(
  '/public/credits/**/*.{jpg,jpeg,png,webp,avif,gif,svg,JPG,JPEG,PNG,WEBP,AVIF,GIF,SVG}',
  {eager: true, query: '?url', import: 'default'},
))
for (let index = photos.length - 1; index > 0; index--) {
  const other = Math.floor(Math.random() * (index + 1))
  const current = photos[index]!
  photos[index] = photos[other]!
  photos[other] = current
}

const guestNames = ref<string[]>([])
const creditRows = computed(() => {
  if (!guestNames.value.length) return []
  const unitCount = Math.max(6, wedding.creditsDepartments.length, photos.length * 3, Math.ceil(guestNames.value.length / 8))
  const units = Array.from({length: unitCount}, (_, unitIndex) => ({
    title: wedding.creditsDepartments[unitIndex % wedding.creditsDepartments.length] ?? '',
    names: Array.from({length: 8}, (_, index) => guestNames.value[(unitIndex * 8 + index) % guestNames.value.length]),
  }))
  const rows: {
    units: typeof units
    photo: string | undefined
    right: boolean
  }[] = []
  let unitIndex = 0
  let photoIndex = 0
  while (unitIndex < units.length) {
    const photo = rows.length % 2 === 1
      ? photos[photoIndex % photos.length]
      : undefined
    const groupCount = photo ? 1 : 2
    rows.push({
      units: units.slice(unitIndex, unitIndex + groupCount),
      photo,
      right: photoIndex % 2 === 1,
    })
    unitIndex += groupCount
    if (photo) photoIndex++
  }
  return rows
})
const duration = computed(() => `${Math.max(55, creditRows.value.length * 24)}s`)

onMounted(async () => {
  if (!supabase) return
  try {
    const {data, error} = await supabase.rpc('guest_credits')
    if (error || !Array.isArray(data)) return
    guestNames.value = data.flatMap((row: { guest_name?: unknown }) =>
      typeof row?.guest_name === 'string' && row.guest_name.trim() ? [row.guest_name.trim()] : [])
  } catch {
    guestNames.value = []
  }

})
</script>

<template>
  <div v-if="guestNames.length" class="guest-credits-backdrop" :style="{'--credits-duration': duration}">
    <ul class="sr-only" aria-label="Nomi degli invitati">
      <li v-for="(name, index) in guestNames" :key="`accessible-${index}`">{{ name }}</li>
    </ul>
    <div class="guest-credits-window" aria-hidden="true">
      <div class="guest-credits-roll">
        <div v-for="copy in 2" :key="copy" class="guest-credits-sequence"
             :class="{'guest-credits-sequence-duplicate': copy === 2}">
          <div v-for="(row, rowIndex) in creditRows" :key="rowIndex" class="guest-credits-row">
            <div class="guest-credits-units">
              <div v-for="(unit, unitIndex) in row.units" :key="unitIndex" class="guest-credits-unit">
                <p v-if="unit.title" class="guest-credits-department">{{ unit.title }}</p>
                <ul>
                  <li v-for="(name, index) in unit.names" :key="index">{{ name }}</li>
                </ul>
              </div>
              <figure v-if="row.photo" class="guest-credits-photo"
                      :class="{'guest-credits-photo-right': row.right}">
                <img :src="row.photo" alt="" width="640" height="480" decoding="async">
              </figure>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
