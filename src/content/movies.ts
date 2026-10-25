import movies from './movies.json'

type MovieDescription = {
  id?: string
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

// The array order is the slideshow order; IDs are optional.
const descriptions: MovieDescription[] = movies

export const upcomingMovies: UpcomingMovie[] = descriptions
  .map((movie, index) => ({
    id: movie.id || `movie-${index + 1}`,
    title: movie.title,
    poster: movie.poster,
    tagline: movie.tagline || '',
    genre: movie.genre || 'Una storia con noi',
    release: movie.release || 'Prossimamente',
    fallbackPoster: movie.fallbackPoster || 'ceremony',
  }))
