import { upcomingMovies } from './movies'

// Empty fields display placeholders. Add your details here when ready.
export const wedding = {
  names: 'Jacopo & Agnese',
  date: '28 maggio 2027',
  location: 'Tenuta Cascina Canova, Bergamo',
  rsvpEmail: '',
  rsvpDeadline: '',
  events: [
    { title: 'La cerimonia', poster: 'ceremony', tagline: 'Una promessa per sempre', time: '', venue: '', address: '', mapsUrl: '', note: 'Il momento del sì. Presto tutti i dettagli per esserci.' },
    { title: 'Un brindisi insieme', poster: 'toast', tagline: 'A noi. E a tutti voi.', time: '', venue: '', address: '', mapsUrl: '', note: 'Il primo brindisi, due chiacchiere e il tempo di ritrovarsi. I dettagli arriveranno presto.' },
    { title: 'A tavola', poster: 'dinner', tagline: 'Le scene migliori, insieme', time: '', venue: '', address: '', mapsUrl: '', note: 'Poi ci si siede a tavola. E si vede dove ci porta la serata.' },
    { title: 'I festeggiamenti', poster: 'party', tagline: 'Il gran finale lo scriviamo noi', time: '', venue: '', address: '', mapsUrl: '', note: 'Il dolce, la musica e ancora un po’ di tempo insieme. Il finale lo scriviamo con voi.' },
  ],
  upcomingMovies,
  gift: {
    title: 'Il prossimo capitolo',
    message: 'Il regalo più bello è avervi con noi. Se desiderate farci un pensiero, potete contribuire alle prossime avventure del nostro film insieme.',
    // Add both fields to display the bank details and enable copying.
    iban: '',
    accountHolder: '',
    reference: 'Regalo matrimonio Jacopo e Agnese',
    placeholder: 'Presto troverete qui le coordinate per chi desidera farci un regalo. Intanto, grazie di essere parte della nostra storia.',
  },
  travel: '',
  accommodation: '',
}
