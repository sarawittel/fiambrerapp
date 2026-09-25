import type { Recipe } from '../data/types';

/** recipeId → número de veces que se quiere fabricar */
export type Plan = Record<string, number>;

export interface CraftStep {
  recipeId: string;
  crafts: number;
}

export interface Requirements {
  /** itemId → cantidad total necesaria */
  materials: Record<string, number>;
  /** fabricaciones intermedias, en orden de ejecución (dependencias primero) */
  steps: CraftStep[];
}

/**
 * Calcula los materiales necesarios para un plan.
 * Con `deep`, desglosa los ingredientes fabricables hasta materias primas,
 * reaprovechando el excedente (p. ej. 1 tronco da 2 tablones).
 */
export function computeRequirements(plan: Plan, recipes: Recipe[], deep: boolean): Requirements {
  const byId = new Map(recipes.map((r) => [r.id, r]));
  const producer = new Map<string, Recipe>();
  for (const r of recipes) if (!producer.has(r.output)) producer.set(r.output, r);

  const materials: Record<string, number> = {};
  const surplus: Record<string, number> = {};
  const crafts = new Map<string, number>();

  const addMaterial = (itemId: string, qty: number) => {
    materials[itemId] = (materials[itemId] ?? 0) + qty;
  };

  function need(itemId: string, qty: number, path: Set<string>) {
    const recipe = deep ? producer.get(itemId) : undefined;
    // Sin receta, o receta circular: se trata como materia prima.
    if (!recipe || path.has(recipe.id)) return addMaterial(itemId, qty);

    const fromSurplus = Math.min(surplus[itemId] ?? 0, qty);
    surplus[itemId] = (surplus[itemId] ?? 0) - fromSurplus;
    const remaining = qty - fromSurplus;
    if (remaining === 0) return;

    const times = Math.ceil(remaining / recipe.outputQty);
    surplus[itemId] += times * recipe.outputQty - remaining;
    craft(recipe, times, path);
  }

  function craft(recipe: Recipe, times: number, path: Set<string>) {
    const next = new Set(path).add(recipe.id);
    for (const ing of recipe.ingredients) need(ing.item, ing.qty * times, next);
    crafts.set(recipe.id, (crafts.get(recipe.id) ?? 0) + times);
  }

  for (const [recipeId, count] of Object.entries(plan)) {
    const recipe = byId.get(recipeId);
    if (!recipe || count <= 0) continue;
    if (deep) {
      craft(recipe, count, new Set());
      crafts.delete(recipe.id); // el objetivo no es un paso intermedio
    } else {
      for (const ing of recipe.ingredients) addMaterial(ing.item, ing.qty * count);
    }
  }

  const steps = [...crafts].map(([recipeId, n]) => ({ recipeId, crafts: n }));
  return { materials, steps };
}
