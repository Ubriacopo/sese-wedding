<script setup lang="ts">
// Coordinates trace the visible light strips in each original image. The SVG
// uses the same bottom-centred cover crop as the background to stay registered.
const scenes = [
  {
    name: 'mobile', width: 941, height: 1672,
    stars: [
      [550.3, 38.7], [278.5, 67], [717.5, 158.5], [430.8, 240.8],
      [737, 297.7], [387.7, 392], [66.3, 466.7], [804.7, 611.3],
      [189.5, 666], [362, 708], [459.5, 826], [58, 876],
      [843.5, 952.5], [329.2, 1007.6], [476.3, 1036.7], [160, 1082.8],
      [584.5, 1097.5], [387.2, 1139.2], [37.7, 1175.5],
    ],
    windows: [
      [426, 1249, 3, 4], [442, 1256, 3, 4], [453, 1262, 3, 4], [453, 1269, 3, 3],
      [648, 1390, 4, 3], [648, 1403, 5, 4], [641, 1414, 4, 3], [662, 1423, 4, 3],
      [354, 1340, 3, 7], [390, 1341, 3, 5], [385, 1349, 2, 6], [380, 1358, 3, 6],
      [380, 1366, 3, 6],
    ],
    beams: [
      'M 823 1349 L 862 1189 L 877 1189 L 827 1348 Z',
      'M 860 1338 L 777 1189 L 797 1189 L 865 1337 Z',
      'M 902 1332 L 941 1189 L 941 1230 L 907 1331 Z',
      'M 191 1450 L 190 1319 L 199 1319 L 199 1450 Z',
      'M 497 1364 L 518 1296 L 530 1296 L 507 1364 Z',
      'M 418 1598 L 439 1598 L 540 1360 L 512 1360 Z',
      'M 483 1574 L 508 1574 L 442 1375 L 412 1375 Z',
    ],
  },
  {
    name: 'desktop', width: 1672, height: 941,
    stars: [
      [1334.3, 12.3], [67.7, 36.7], [373.1, 43.7], [1593.3, 77.5],
      [256.5, 169], [402.5, 189.8], [1406, 207.8], [106.9, 237.5],
      [983, 291], [104.5, 330],
    ],
    windows: [
      [745, 376, 4, 4], [761, 384, 4, 4], [761, 392, 4, 4], [1124, 561, 7, 4],
      [1135, 569, 6, 4], [1166, 577, 6, 4], [1135, 593, 6, 4], [1155, 601, 7, 3],
      [1124, 617, 7, 3], [1155, 624, 7, 4], [1166, 632, 6, 4], [648, 489, 5, 7],
      [702, 489, 6, 7], [695, 499, 5, 7], [687, 510, 5, 7], [656, 521, 5, 7],
      [671, 531, 5, 7], [656, 542, 5, 7],
    ],
    beams: [
      'M 1535 618 L 1574 459 L 1589 459 L 1540 616 Z',
      'M 1583 605 L 1500 459 L 1520 459 L 1588 604 Z',
      'M 1638 599 L 1672 475 L 1672 515 L 1643 598 Z',
      'M 338 678 L 337 506 L 350 506 L 350 678 Z',
      'M 856 517 L 872 477 L 894 477 L 875 513 Z',
      'M 744 820 L 777 820 L 908 490 L 872 490 Z',
      'M 839 787 L 873 787 L 760 500 L 720 500 Z',
    ],
  },
]
</script>

<template>
  <div class="hollywood-lights" aria-hidden="true">
    <svg v-for="scene in scenes" :key="scene.name" :class="`hollywood-lights-${scene.name}`"
         :viewBox="`0 0 ${scene.width} ${scene.height}`" preserveAspectRatio="xMidYMax slice">
      <defs>
        <linearGradient :id="`searchlight-${scene.name}`" x1="0" y1="1" x2="0" y2="0">
          <stop stop-color="#c6f4d4" stop-opacity=".7" />
          <stop offset=".55" stop-color="#c6f4d4" stop-opacity=".3" />
          <stop offset="1" stop-color="#c6f4d4" stop-opacity="0" />
        </linearGradient>
        <linearGradient :id="`rooftop-${scene.name}`" x1="0" y1="1" x2="0" y2="0">
          <stop stop-color="#fff0bd" stop-opacity=".6" />
          <stop offset=".5" stop-color="#fff0bd" stop-opacity=".2" />
          <stop offset="1" stop-color="#fff0bd" stop-opacity="0" />
        </linearGradient>
      </defs>
      <path v-for="(beam, index) in scene.beams" :key="beam" :d="beam"
            class="hollywood-searchlight" :style="{ animationDelay: `${index * -2.7}s`, animationDuration: `${7 + index * 1.3}s` }"
            :fill="`url(#${index >= 5 ? 'rooftop' : 'searchlight'}-${scene.name})`" />
      <g v-for="(star, index) in scene.stars" :key="`star-${index}`" class="hollywood-star"
         :style="{ animationDelay: `${index * -1.9}s`, animationDuration: `${4 + index % 5}s` }">
        <circle :cx="star[0]" :cy="star[1]" r="4" fill="#e7ffe2" opacity=".1" />
        <circle :cx="star[0]" :cy="star[1]" :r="index % 3 === 0 ? 1.8 : 1.2" fill="#e7ffe2" />
      </g>
      <rect v-for="(pane, index) in scene.windows" :key="`window-${index}`"
            :x="pane[0]" :y="pane[1]" :width="pane[2]" :height="pane[3]"
            class="hollywood-window" fill="#ffe3a0"
            :style="{ animationDelay: `${index * -3.7}s`, animationDuration: `${17 + index % 7 * 3}s` }" />
    </svg>
  </div>
</template>
