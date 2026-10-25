<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import CinemaPoster from './CinemaPoster.vue'
import { wedding } from '../content/wedding'
import type { UpcomingMovie } from '../content/movies'

const props = defineProps<{ movies: UpcomingMovie[] }>()
const activeIndex = ref(0)
const failedPosters = ref(new Set<string>())
const activeMovie = computed(() => props.movies[activeIndex.value])
function getPosterUrl(movie: UpcomingMovie) {
  const path = movie.poster.trim()
  if (!path || /^(https?:)?\/\//.test(path)) return path
  return `${import.meta.env.BASE_URL}posters/${path.replace(/^\/+/, '')}`
}

function goTo(index: number) {
  if (!props.movies.length) return
  activeIndex.value = (index + props.movies.length) % props.movies.length
}

watch(() => props.movies.length, () => {
  if (activeIndex.value >= props.movies.length) activeIndex.value = 0
})
</script>

<template>
  <div v-if="activeMovie" class="movie-carousel" role="region" aria-roledescription="carosello" aria-label="I nostri prossimi film"
       @keydown.left.prevent="goTo(activeIndex - 1)" @keydown.right.prevent="goTo(activeIndex + 1)">
    <div class="movie-feature">
      <article v-for="(movie, index) in movies" :key="movie.id" class="movie-slide" :class="{ 'is-active': index === activeIndex }"
               role="group" aria-roledescription="diapositiva" :aria-hidden="index !== activeIndex" :inert="index !== activeIndex"
               :aria-label="`${index + 1} di ${movies.length}: ${movie.title}`">
        <div class="movie-poster-stage">
          <div class="movie-poster-hanger" aria-hidden="true">Prossimamente su nessuno schermo</div>
          <div v-if="getPosterUrl(movie) && !failedPosters.has(getPosterUrl(movie))" class="poster-case movie-photo-poster">
            <img :src="getPosterUrl(movie)" :alt="`Locandina di ${movie.title}`" width="600" height="900" decoding="async" @error="failedPosters.add(getPosterUrl(movie))" />
          </div>
          <CinemaPoster v-else :title-id="`movie-poster-${movie.id}`" :title="movie.title" :poster="movie.fallbackPoster"
                        :tagline="movie.tagline" :billing="wedding.names" class="movie-designed-poster">
            {{ movie.genre }} · {{ movie.release }}
          </CinemaPoster>
        </div>
        <div class="movie-caption">
          <p class="movie-genre">{{ movie.genre }}</p>
          <h3 class="font-title text-2xl font-semibold uppercase leading-tight tracking-[0.02em] sm:text-3xl">{{ movie.title }}</h3>
          <p v-if="movie.tagline" class="mt-1 font-serif text-base italic leading-snug text-olive sm:text-lg">{{ movie.tagline }}</p>
        </div>
      </article>
    </div>
    <div v-if="movies.length > 1" class="movie-controls">
      <button type="button" class="movie-arrow" aria-label="Film precedente" @click="goTo(activeIndex - 1)"><span aria-hidden="true">←</span></button>
      <div class="movie-pagination" aria-label="Scegli un film">
        <button v-for="(movie, index) in movies" :key="movie.id" type="button" class="movie-dot"
                :class="{ 'is-active': index === activeIndex }" :aria-label="`Mostra ${movie.title}`"
                :aria-current="index === activeIndex ? 'true' : undefined" @click="goTo(index)">
          <span aria-hidden="true">{{ String(index + 1).padStart(2, '0') }}</span>
        </button>
      </div>
      <button type="button" class="movie-arrow" aria-label="Film successivo" @click="goTo(activeIndex + 1)"><span aria-hidden="true">→</span></button>
    </div>
    <p class="sr-only" role="status" aria-live="polite" aria-atomic="true">Film {{ activeIndex + 1 }} di {{ movies.length }}: {{ activeMovie.title }}</p>
  </div>
</template>

<style scoped>
.movie-carousel { min-width: 0; max-width: 44rem; margin-inline: auto; }
/* Overlapping slides all contribute to the grid's size, keeping the largest fit. */
.movie-feature { display: grid; border: 1px solid var(--color-line); background: var(--color-panel); }
.movie-slide { grid-area: 1 / 1; display: grid; min-width: 0; visibility: hidden; opacity: 0; pointer-events: none; transition: opacity 160ms ease; }
.movie-slide.is-active { visibility: visible; opacity: 1; pointer-events: auto; }
.movie-poster-stage { padding: .75rem; background: #252c23; }
.movie-poster-hanger { margin: 0 auto .5rem; text-align: center; font-family: 'Courier New', monospace; font-size: .5rem; text-transform: uppercase; letter-spacing: .12em; line-height: 1.6; color: #c0c7a8; }
.movie-designed-poster, .movie-photo-poster { max-width: 14rem; margin-inline: auto; box-shadow: 0 6px 16px #0004; padding: .4rem; }
.movie-photo-poster img { display: block; width: 100%; height: auto; aspect-ratio: 2 / 3; object-fit: contain; background: #20271f; }
.movie-designed-poster :deep(.event-poster) { padding: .75rem; gap: .5rem; }
.movie-designed-poster :deep(.poster-title) { font-family: var(--font-title); font-size: 1.5rem; font-weight: 600; text-transform: uppercase; letter-spacing: .02em; }
.movie-designed-poster :deep(.poster-tagline) { font-size: .65rem; }
.movie-designed-poster :deep(.poster-art) { stroke-width: 1.5; }
.movie-designed-poster :deep(.poster-billing) { font-size: .5rem; }
.movie-caption { padding: 1.25rem; align-self: center; min-width: 0; text-align: center; }
.movie-genre { margin-bottom: .5rem; font-size: .6rem; line-height: 1.5; letter-spacing: .12em; text-transform: uppercase; color: var(--color-olive); }
.movie-controls { display: flex; justify-content: center; align-items: center; gap: .5rem; padding-top: .75rem; }
.movie-arrow { width: 2.75rem; min-height: 2.75rem; border: 1px solid var(--color-olive); font-size: 1.25rem; color: var(--color-olive); cursor: pointer; }
.movie-pagination { display: flex; flex-wrap: wrap; justify-content: center; gap: .25rem; }
.movie-dot { min-width: 2.75rem; min-height: 2.75rem; padding: .5rem; font-family: 'Courier New', monospace; font-size: .75rem; border-bottom: 2px solid transparent; cursor: pointer; }
.movie-dot.is-active { border-color: var(--color-olive); color: var(--color-olive); }
.movie-arrow:hover, .movie-dot:hover { background: var(--color-panel); }
@media (min-width: 640px) {
  .movie-slide { grid-template-columns: minmax(0, 18rem) minmax(0, 1fr); }
  .movie-designed-poster, .movie-photo-poster { max-width: 16rem; }
  .movie-caption { padding: 1.5rem; text-align: left; }
}
@media (prefers-reduced-motion: reduce) {
  .movie-slide { transition: none; }
}
</style>
