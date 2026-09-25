import { describe, expect, it } from 'vitest';
import { characters, dayById, itemById, items, recipes } from '../data';

// Comprueba que los datos editados a mano no tienen referencias rotas.
describe('integridad de datos', () => {
  it('ids de objeto únicos', () => {
    expect(new Set(items.map((i) => i.id)).size).toBe(items.length);
  });

  it('las recetas solo usan objetos existentes', () => {
    for (const r of recipes) {
      expect(itemById.has(r.output), `${r.id} → ${r.output}`).toBe(true);
      for (const ing of r.ingredients) expect(itemById.has(ing.item), `${r.id} → ${ing.item}`).toBe(true);
    }
  });

  it('los personajes usan días y objetos existentes', () => {
    for (const c of characters) {
      for (const d of c.days) expect(dayById.has(d), `${c.id} → día ${d}`).toBe(true);
      for (const i of [...(c.sells ?? []), ...(c.buys ?? [])]) expect(itemById.has(i), `${c.id} → ${i}`).toBe(true);
    }
  });
});
