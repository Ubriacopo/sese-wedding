type MovieDescription = {
  title: string
  poster: string
  tagline?: string
  genre?: string
  release?: string
  fallbackPoster?: string
}

export type UpcomingMovie = {
  id: string
  title: string
  poster: string
  tagline: string
  genre: string
  release: string
  fallbackPoster: string
}

// One JSON per movie, ordered by filename. No separate list to maintain.
const descriptions = import.meta.glob<MovieDescription>('./movies/*.json', {
  eager: true,
  import: 'default',
})

export const upcomingMovies: UpcomingMovie[] = Object.entries(descriptions)
  .sort(([first], [second]) => first.localeCompare(second))
  .map(([path, movie]) => ({
    id: path.slice(path.lastIndexOf('/') + 1, -5),
    title: movie.title,
    poster: movie.poster,
    tagline: movie.tagline || '',
    genre: movie.genre || 'Una storia con noi',
    release: movie.release || 'Prossimamente',
    fallbackPoster: movie.fallbackPoster || 'ceremony',
  }))
