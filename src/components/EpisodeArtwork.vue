<script setup lang="ts">
defineProps<{ art: string }>()
</script>

<template>
  <div class="event-poster" :class="`poster-${art}`">
      <svg class="poster-art" viewBox="0 0 200 180" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
        <g v-if="art === 'ceremony'">
          <circle cx="77" cy="100" r="39" /><circle cx="123" cy="100" r="39" />
          <path d="m100 20 5 13 14 1-11 9 3 14-11-8-11 8 3-14-11-9 14-1Z" />
        </g>
        <g v-else-if="art === 'toast'">
          <path d="m47 37 45 17-16 42a24 24 0 0 1-45-17Zm-3 80-12 32m-16-6 32 12M153 37l-45 17 16 42a24 24 0 0 0 45-17Zm3 80 12 32m16-6-32 12M100 12v17m-20-9 8 13m32-13-8 13M39 65l43 16m36 0 43-16" />
        </g>
        <g v-else-if="art === 'dinner'">
          <circle cx="100" cy="90" r="57" /><circle cx="100" cy="90" r="43" />
          <path d="M20 32v116m-9-116v29q9 16 18 0V32M179 148V32q-18 18-12 64h12" />
          <path d="m100 65 7 16 18 2-14 12 4 18-15-9-15 9 4-18-14-12 18-2Z" />
        </g>
        <g v-else>
          <circle cx="100" cy="93" r="57" /><circle cx="100" cy="93" r="39" /><circle cx="100" cy="93" r="17" /><circle cx="100" cy="93" r="3" />
          <path d="m150 23 4 10 11 1-9 7 3 11-9-6-9 6 3-11-9-7 11-1ZM36 17v20m-10-10h20M164 139v20m-10-10h20M70 49a48 48 0 0 1 54-3M76 136a48 48 0 0 0 54-3" />
        </g>
      </svg>
  </div>
</template>
