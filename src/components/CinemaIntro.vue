<script setup lang="ts">
import { nextTick, onMounted, onUnmounted, ref } from 'vue'

type YouTubePlayer = { destroy: () => void, unMute: () => void, playVideo: () => void, getPlayerState: () => number }
type YouTubeEvent = { data?: number, target: YouTubePlayer }
type YouTubeWindow = Window & {
  YT?: { Player: new (element: HTMLIFrameElement, options: { events: Record<string, (event: YouTubeEvent) => void> }) => YouTubePlayer }
  onYouTubeIframeAPIReady?: () => void
}

const visible = ref(false)
const fading = ref(false)
const playing = ref(false)
const soundEnabled = ref(false)
const video = ref<HTMLIFrameElement>()
const youtube = window as YouTubeWindow
const videoUrl = `https://www.youtube.com/embed/Jend9hCJ8wU?autoplay=1&mute=1&playsinline=1&enablejsapi=1&origin=${encodeURIComponent(window.location.origin)}`
let player: YouTubePlayer | undefined
let timeout: ReturnType<typeof setTimeout> | undefined
let closeTimer: ReturnType<typeof setTimeout> | undefined
let apiScript: HTMLScriptElement | undefined
let previousApiReady: (() => void) | undefined

function closeIntro() {
  if (fading.value || !visible.value) return
  fading.value = true
  if (timeout) clearTimeout(timeout)
  closeTimer = setTimeout(() => { visible.value = false }, 600)
}

function enableSound() {
  player?.unMute()
  player?.playVideo()
  soundEnabled.value = true
}

function markPlaying() {
  playing.value = true
  if (timeout) clearTimeout(timeout)
  // A final fallback protects the page if the video never reports completion.
  timeout = setTimeout(closeIntro, 60000)
}

function createPlayer() {
  if (!visible.value || !youtube.YT || !video.value) return
  player = new youtube.YT.Player(video.value, {
    events: {
      onReady: (event) => {
        if (event.target.getPlayerState() === 1) markPlaying()
      },
      onStateChange: (event) => {
        if (event.data === 1) markPlaying()
        else if (event.data === 0) closeIntro()
      },
      onError: closeIntro,
      onAutoplayBlocked: closeIntro,
    },
  })
}

onMounted(async () => {
  // Direct invitation links should reach the RSVP without an interstitial.
  if (window.location.hash || window.location.search || window.matchMedia('(prefers-reduced-motion: reduce)').matches) return
  visible.value = true
  await nextTick()
  timeout = setTimeout(closeIntro, 10000)
  if (youtube.YT?.Player) {
    createPlayer()
  } else {
    previousApiReady = youtube.onYouTubeIframeAPIReady
    youtube.onYouTubeIframeAPIReady = () => { previousApiReady?.(); createPlayer() }
    apiScript = document.createElement('script')
    apiScript.src = 'https://www.youtube.com/iframe_api'
    apiScript.onerror = closeIntro
    document.head.appendChild(apiScript)
  }
})
onUnmounted(() => {
  if (timeout) clearTimeout(timeout)
  if (closeTimer) clearTimeout(closeTimer)
  player?.destroy()
  if (apiScript) {
    apiScript.remove()
    youtube.onYouTubeIframeAPIReady = previousApiReady
  }
})
</script>

<template>
  <div v-if="visible" class="intro" :class="{ 'is-fading': fading }">
    <div class="intro-player">
      <iframe ref="video" :src="videoUrl" title="Universal Pictures 100th Anniversary Logo Intro" allow="autoplay; encrypted-media; picture-in-picture" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>
    </div>
    <p v-if="!playing" class="intro-loading" role="status">Caricamento introduzione…</p>
    <div class="intro-actions">
      <button v-if="playing && !soundEnabled" type="button" @click="enableSound">Attiva audio</button>
      <button type="button" @click="closeIntro">Salta l’introduzione <span aria-hidden="true">→</span></button>
    </div>
  </div>
</template>

<style scoped>
.intro { position: fixed; z-index: 100; inset: 0; display: flex; align-items: center; justify-content: center; background: #000; color: #fff; transition: opacity .6s ease; }
.intro.is-fading { opacity: 0; pointer-events: none; }
.intro-player { position: relative; width: min(100vw, 177.78vh); aspect-ratio: 16 / 9; }
.intro-player iframe { position: absolute; inset: 0; width: 100%; height: 100%; border: 0; }
.intro-loading { position: absolute; top: 1rem; left: 1rem; font-size: .75rem; }
.intro-actions { position: absolute; right: 1rem; bottom: max(1rem, env(safe-area-inset-bottom)); display: flex; flex-wrap: wrap; justify-content: flex-end; gap: .5rem; }
.intro-actions button { min-height: 44px; border: 1px solid #ffffff80; padding: .5rem 1rem; color: #fff; background: #071321e6; font-size: .75rem; cursor: pointer; }
.intro-actions button:focus-visible { outline: 2px solid white; outline-offset: 3px; }
@media (prefers-reduced-motion: reduce) { .intro { transition: none; } }
</style>
