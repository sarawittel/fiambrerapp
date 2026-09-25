/** Minúsculas y sin tildes, para búsquedas tolerantes. */
export function normalize(s: string) {
  return s.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase();
}
