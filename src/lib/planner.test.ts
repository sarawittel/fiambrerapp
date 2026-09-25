import { describe, expect, it } from 'vitest';
import type { Recipe } from '../data/types';
import { computeRequirements } from './planner';

const recipes: Recipe[] = [
  { id: 'r_plank', output: 'plank', outputQty: 2, station: 'x', ingredients: [{ item: 'log', qty: 1 }] },
  { id: 'r_bar', output: 'bar', outputQty: 1, station: 'x', ingredients: [{ item: 'ore', qty: 3 }, { item: 'log', qty: 1 }] },
  { id: 'r_nails', output: 'nails', outputQty: 5, station: 'x', ingredients: [{ item: 'bar', qty: 1 }] },
  { id: 'r_coffin', output: 'coffin', outputQty: 1, station: 'x', ingredients: [{ item: 'plank', qty: 4 }, { item: 'nails', qty: 6 }] },
  { id: 'r_shelf', output: 'shelf', outputQty: 1, station: 'x', ingredients: [{ item: 'plank', qty: 1 }] },
];

describe('computeRequirements', () => {
  it('sin desglose devuelve los ingredientes directos', () => {
    const { materials, steps } = computeRequirements({ r_coffin: 2 }, recipes, false);
    expect(materials).toEqual({ plank: 8, nails: 12 });
    expect(steps).toEqual([]);
  });

  it('desglosa hasta materias primas redondeando por lote', () => {
    const { materials, steps } = computeRequirements({ r_coffin: 1 }, recipes, true);
    // 4 tablones = 2 troncos; 6 clavos = 2 lotes = 2 lingotes = 6 mineral + 2 troncos
    expect(materials).toEqual({ log: 4, ore: 6 });
    expect(steps).toEqual([
      { recipeId: 'r_plank', crafts: 2 },
      { recipeId: 'r_bar', crafts: 2 },
      { recipeId: 'r_nails', crafts: 2 },
    ]);
  });

  it('reaprovecha el excedente entre recetas distintas', () => {
    // dos estanterías necesitan 1 tablón cada una: basta 1 tronco
    const { materials } = computeRequirements({ r_shelf: 2 }, recipes, true);
    expect(materials).toEqual({ log: 1 });
  });

  it('no entra en bucle con recetas circulares', () => {
    const cyclic: Recipe[] = [
      { id: 'a', output: 'A', outputQty: 1, station: 'x', ingredients: [{ item: 'B', qty: 1 }] },
      { id: 'b', output: 'B', outputQty: 1, station: 'x', ingredients: [{ item: 'A', qty: 1 }] },
    ];
    expect(computeRequirements({ a: 1 }, cyclic, true).materials).toEqual({ A: 1 });
  });

  it('ignora recetas desconocidas y cantidades nulas', () => {
    expect(computeRequirements({ nope: 3, r_shelf: 0 }, recipes, true).materials).toEqual({});
  });
});
