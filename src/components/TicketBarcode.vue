<script setup lang="ts">
import { computed } from 'vue'

const props = defineProps<{ code: string }>()

// Code 39 digit patterns: nine alternating bars/spaces, with three wide elements.
// Pattern reference: https://github.com/zxing/zxing/blob/master/core/src/main/java/com/google/zxing/oned/Code39Reader.java
const digits = [0x034, 0x121, 0x061, 0x160, 0x031, 0x130, 0x070, 0x025, 0x124, 0x064]
const barcode = computed(() => {
  const bars: { x: number, width: number }[] = []
  let x = 10 // Quiet zone on both sides of the barcode.
  const patterns = [0x094, ...Array.from(props.code, digit => digits[Number(digit)]!), 0x094]
  for (const pattern of patterns) {
    for (let element = 0; element < 9; element += 1) {
      const width = pattern & (1 << (8 - element)) ? 3 : 1
      if (element % 2 === 0) bars.push({ x, width })
      x += width
    }
    x += 1
  }
  return { bars, width: x + 9 }
})
</script>

<template>
  <figure class="ticket-barcode">
    <svg :viewBox="`0 0 ${barcode.width} 44`" role="img" :aria-label="`Codice a barre del biglietto ${code}`" shape-rendering="crispEdges">
      <rect :width="barcode.width" height="44" fill="#eee7d4" />
      <rect v-for="bar in barcode.bars" :key="bar.x" :x="bar.x" y="4" :width="bar.width" height="36" fill="#252c23" />
    </svg>
    <figcaption>{{ code }}</figcaption>
  </figure>
</template>

<style scoped>
.ticket-barcode { width: clamp(105px, 35vw, 160px); flex-shrink: 0; text-align: center; }
svg { display: block; width: 100%; height: 44px; }
figcaption { margin-top: .15rem; font: .6rem 'Courier New', monospace; letter-spacing: .2em; }
</style>
