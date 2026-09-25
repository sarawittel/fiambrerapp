import type { Recipe } from './types';

// DATOS DE EJEMPLO: completa con las recetas reales del juego.
export const recipes: Recipe[] = [
  { id: 'r_plank', output: 'plank', outputQty: 2, station: 'Banco de carpintería', ingredients: [{ item: 'log', qty: 1 }], time: 1 },
  { id: 'r_stone_block', output: 'stone_block', outputQty: 1, station: 'Banco de cantero', ingredients: [{ item: 'stone', qty: 2 }], time: 1 },
  { id: 'r_iron_bar', output: 'iron_bar', outputQty: 1, station: 'Horno', ingredients: [{ item: 'iron_ore', qty: 3 }, { item: 'log', qty: 1 }], time: 2 },
  { id: 'r_nails', output: 'nails', outputQty: 5, station: 'Yunque', ingredients: [{ item: 'iron_bar', qty: 1 }], time: 1 },
  { id: 'r_flour', output: 'flour', outputQty: 1, station: 'Molino', ingredients: [{ item: 'wheat', qty: 2 }], time: 1 },
  { id: 'r_bread', output: 'bread', outputQty: 1, station: 'Horno', ingredients: [{ item: 'flour', qty: 2 }, { item: 'water', qty: 1 }], time: 2 },
  { id: 'r_burger', output: 'burger', outputQty: 1, station: 'Cocina', ingredients: [{ item: 'bread', qty: 1 }, { item: 'flesh', qty: 1 }], time: 1, notes: 'Se vende bien en la taberna.' },
  { id: 'r_candle', output: 'candle', outputQty: 3, station: 'Banco de trabajo', ingredients: [{ item: 'beeswax', qty: 2 }, { item: 'fat', qty: 1 }], time: 1 },
  { id: 'r_paper', output: 'paper', outputQty: 2, station: 'Prensa', ingredients: [{ item: 'plank', qty: 1 }, { item: 'water', qty: 1 }], time: 2 },
  { id: 'r_ink', output: 'ink', outputQty: 1, station: 'Mesa de alquimia', ingredients: [{ item: 'herb_blue', qty: 1 }, { item: 'water', qty: 1 }], time: 1 },
  { id: 'r_potion_heal', output: 'potion_heal', outputQty: 1, station: 'Mesa de alquimia', ingredients: [{ item: 'herb_red', qty: 2 }, { item: 'water', qty: 1 }], time: 1 },
  { id: 'r_scroll', output: 'scroll', outputQty: 1, station: 'Escritorio', ingredients: [{ item: 'paper', qty: 1 }, { item: 'ink', qty: 1 }], time: 1 },
  { id: 'r_coffin', output: 'coffin', outputQty: 1, station: 'Banco de carpintería', ingredients: [{ item: 'plank', qty: 4 }, { item: 'nails', qty: 6 }], time: 3 },
  { id: 'r_gravestone', output: 'gravestone', outputQty: 1, station: 'Banco de cantero', ingredients: [{ item: 'stone_block', qty: 2 }, { item: 'iron_bar', qty: 1 }], time: 3, notes: 'Sube la calidad de la tumba.' },
];
