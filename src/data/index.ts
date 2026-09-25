import { characters } from './characters';
import { days } from './days';
import { items } from './items';
import { recipes } from './recipes';

export { characters, days, items, recipes };
export type * from './types';

export const itemById = new Map(items.map((i) => [i.id, i]));
export const recipeById = new Map(recipes.map((r) => [r.id, r]));
export const characterById = new Map(characters.map((c) => [c.id, c]));
export const dayById = new Map(days.map((d) => [d.id, d]));

/** Primera receta que produce cada objeto. */
export const recipeForItem = new Map<string, (typeof recipes)[number]>();
for (const r of recipes) if (!recipeForItem.has(r.output)) recipeForItem.set(r.output, r);

export const stations = [...new Set(recipes.map((r) => r.station))].sort((a, b) => a.localeCompare(b, 'es'));

export function isAvailableOn(c: (typeof characters)[number], dayId: string) {
  return c.days.length === 0 || c.days.includes(dayId);
}

export function sellersOf(itemId: string) {
  return characters.filter((c) => c.sells?.includes(itemId));
}

export function recipesUsing(itemId: string) {
  return recipes.filter((r) => r.ingredients.some((i) => i.item === itemId));
}
