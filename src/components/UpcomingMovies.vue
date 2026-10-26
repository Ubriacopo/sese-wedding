<script setup lang="ts">
import { nextTick, onMounted, onUnmounted, ref, watch } from 'vue'
import CinemaPoster from './CinemaPoster.vue'
import { wedding } from '../content/wedding'
import type { UpcomingMovie } from '../content/movies'

const props = defineProps<{ movies: UpcomingMovie[] }>()
const movieTrack = ref<HTMLElement>()
const canScrollBack = ref(false)
const canScrollForward = ref(false)
const failedPosters = ref(new Set<string>())
let resizeObserver: ResizeObserver | undefined

function getPosterUrl(movie: UpcomingMovie) {
  const path = movie.poster.trim()
  if (!path || /^(https?:)?\/\//.test(path)) return path
  return `${import.meta.env.BASE_URL}posters/${path.replace(/^\/+/, '')}`
}

function updateScrollState() {
  const track = movieTrack.value
  if (!track) return
  canScrollBack.value = track.scrollLeft > 2
  canScrollForward.value = track.scrollLeft + track.clientWidth < track.scrollWidth - 2
}

function scrollMovies(direction: number) {
  const track = movieTrack.value
  if (!track) return
  const firstCard = track.children[0] as HTMLElement | undefined
  const secondCard = track.children[1] as HTMLElement | undefined
  const distance = firstCard && secondCard ? secondCard.offsetLeft - firstCard.offsetLeft : track.clientWidth
  track.scrollBy({
    left: direction * distance,
    behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'instant' : 'smooth',
  })
}

onMounted(() => {
  resizeObserver = new ResizeObserver(updateScrollState)
  if (movieTrack.value) resizeObserver.observe(movieTrack.value)
  updateScrollState()
})
onUnmounted(() => resizeObserver?.disconnect())
watch(() => props.movies, async () => {
  await nextTick()
  updateScrollState()
}, { deep: true })
</script>

<template>
  <div v-if="movies.length" class="movie-library" role="region" aria-label="I nostri prossimi film">
    <div class="movie-library-toolbar">
      <p class="movie-library-label">Prossimamente su nessuno schermo</p>
      <div v-if="canScrollBack || canScrollForward" class="movie-controls">
        <button type="button" class="movie-arrow" aria-label="Film precedenti" aria-controls="upcoming-movie-track" :disabled="!canScrollBack" @click="scrollMovies(-1)"><span aria-hidden="true">←</span></button>
        <button type="button" class="movie-arrow" aria-label="Film successivi" aria-controls="upcoming-movie-track" :disabled="!canScrollForward" @click="scrollMovies(1)"><span aria-hidden="true">→</span></button>
      </div>
    </div>
    <div id="upcoming-movie-track" ref="movieTrack" class="movie-track" tabindex="0" aria-label="Scorri le locandine dei prossimi film"
         @scroll.passive="updateScrollState" @keydown.left.prevent="scrollMovies(-1)" @keydown.right.prevent="scrollMovies(1)">
      <article v-for="movie in movies" :key="movie.id" class="movie-card" :aria-labelledby="`movie-title-${movie.id}`">
        <div class="movie-poster-stage">
          <div v-if="getPosterUrl(movie) && !failedPosters.has(getPosterUrl(movie))" class="movie-photo-poster">
            <img :src="getPosterUrl(movie)" :alt="`Locandina di ${movie.title}`" width="600" height="900" loading="lazy" decoding="async" @error="failedPosters.add(getPosterUrl(movie))" />
          </div>
          <CinemaPoster v-else :title-id="`movie-poster-${movie.id}`" :title="movie.title" :poster="movie.fallbackPoster"
                        :tagline="movie.tagline" :billing="wedding.names" class="movie-designed-poster">
            {{ movie.genre }} · {{ movie.release }}
          </CinemaPoster>
        </div>
        <div class="movie-caption">
          <p class="movie-genre"><span>{{ movie.genre }}</span><span class="movie-release">{{ movie.release }}</span></p>
          <h3 :id="`movie-title-${movie.id}`" class="font-title text-lg font-semibold uppercase leading-tight tracking-[0.02em] sm:text-xl">{{ movie.title }}</h3>
          <p v-if="movie.tagline" class="mt-2 font-serif text-sm italic leading-snug text-olive">{{ movie.tagline }}</p>
        </div>
      </article>
    </div>
  </div>
</template>

<style scoped>
.movie-library { min-width: 0; }
.movie-library-toolbar { display: flex; justify-content: space-between; align-items: center; gap: 1rem; margin-bottom: 1rem; }
.movie-library-label { font-family: 'Courier New', monospace; font-size: .6rem; text-transform: uppercase; letter-spacing: .12em; line-height: 1.7; color: var(--color-olive); }
.movie-track { display: grid; grid-auto-flow: column; grid-auto-columns: 78%; gap: 1rem; overflow-x: auto; overscroll-behavior-x: contain; scroll-snap-type: x mandatory; scrollbar-width: thin; scrollbar-color: var(--color-olive) transparent; padding: .5rem .25rem 1rem; }
.movie-track:focus-visible { outline: 2px solid var(--color-olive); outline-offset: 4px; }
.movie-card { min-width: 0; scroll-snap-align: start; background: var(--color-panel); border: 1px solid var(--color-line); }
.movie-poster-stage { background: #252c23; }
.movie-designed-poster, .movie-photo-poster { width: 100%; }
.movie-designed-poster { padding: 0; border: 0; box-shadow: none; }
.movie-designed-poster::after { display: none; }
.movie-photo-poster img { display: block; width: 100%; height: auto; aspect-ratio: 2 / 3; object-fit: contain; background: #20271f; }
.movie-designed-poster :deep(.event-poster) { padding: .75rem; gap: .5rem; }
.movie-designed-poster :deep(.poster-title) { font-family: var(--font-title); font-size: 1.5rem; font-weight: 600; text-transform: uppercase; letter-spacing: .02em; }
.movie-designed-poster :deep(.poster-tagline) { font-size: .65rem; }
.movie-designed-poster :deep(.poster-art) { stroke-width: 1.5; }
.movie-designed-poster :deep(.poster-billing) { font-size: .5rem; }
.movie-caption { padding: 1rem; min-width: 0; }
.movie-genre { margin-bottom: .5rem; font-size: .55rem; line-height: 1.6; letter-spacing: .1em; text-transform: uppercase; color: var(--color-olive); }
.movie-release { display: block; margin-top: .15rem; }
.movie-controls { display: none; gap: .5rem; flex-shrink: 0; }
.movie-arrow { width: 2.75rem; min-height: 2.75rem; border: 1px solid var(--color-olive); font-size: 1.25rem; color: var(--color-olive); cursor: pointer; }
.movie-arrow:disabled { opacity: .3; cursor: default; }
.movie-arrow:hover:enabled { background: var(--color-panel); }
@media (min-width: 640px) {
  .movie-controls { display: flex; }
  .movie-release { display: inline; margin-top: 0; }
  .movie-release::before { content: ' · '; }
  .movie-track { grid-auto-columns: 42%; gap: 1.25rem; }
}
@media (min-width: 1024px) {
  .movie-track { grid-auto-columns: 28%; gap: 1.5rem; }
}
</style>
