import type { Item } from './types';

// DATOS DE EJEMPLO: completa con los objetos reales del juego.
export const items: Item[] = [
  // Materias primas
  { id: 'log', name: 'Tronco', category: 'material', icon: 'log', sources: ['Talar árboles en el bosque'] },
  { id: 'stone', name: 'Piedra', category: 'material', icon: 'stone', sources: ['Cantera al este del cementerio'] },
  { id: 'iron_ore', name: 'Mineral de hierro', category: 'material', icon: 'ore', sources: ['Cantera (vetas oscuras)'] },
  { id: 'bone', name: 'Hueso', category: 'material', icon: 'bone', sources: ['Mesa de autopsias'] },
  { id: 'flesh', name: 'Carne dudosa', category: 'material', icon: 'meat', sources: ['Mesa de autopsias'] },
  { id: 'fat', name: 'Grasa', category: 'material', icon: 'fat', sources: ['Mesa de autopsias'] },
  { id: 'beeswax', name: 'Cera de abeja', category: 'material', icon: 'wax', sources: ['Colmenas'] },
  { id: 'herb_red', name: 'Hierba roja', category: 'material', icon: 'herb', sources: ['Huerto', 'Claros del bosque'] },
  { id: 'herb_blue', name: 'Hierba azul', category: 'material', icon: 'herb_blue', sources: ['Pantano'] },
  { id: 'water', name: 'Agua', category: 'material', icon: 'water', sources: ['Pozo del cementerio'] },
  { id: 'wheat', name: 'Trigo', category: 'material', icon: 'wheat', sources: ['Huerto'] },

  // Intermedios
  { id: 'plank', name: 'Tablón', category: 'material', icon: 'plank' },
  { id: 'stone_block', name: 'Bloque de piedra', category: 'material', icon: 'stone' },
  { id: 'iron_bar', name: 'Lingote de hierro', category: 'material', icon: 'ingot' },
  { id: 'nails', name: 'Clavos', category: 'material', icon: 'nails' },
  { id: 'flour', name: 'Harina', category: 'comida', icon: 'sack' },
  { id: 'paper', name: 'Papel', category: 'material', icon: 'scroll' },
  { id: 'ink', name: 'Tinta', category: 'alquimia', icon: 'potion_dark' },

  // Productos
  { id: 'candle', name: 'Vela', category: 'funerario', icon: 'candle', description: 'Ilumina la iglesia y mejora la calidad del sermón.' },
  { id: 'bread', name: 'Pan', category: 'comida', icon: 'bread' },
  { id: 'burger', name: 'Hamburguesa dudosa', category: 'comida', icon: 'burger', description: 'Mejor no preguntar de dónde sale la carne.' },
  { id: 'potion_heal', name: 'Poción de vitalidad', category: 'alquimia', icon: 'potion' },
  { id: 'scroll', name: 'Pergamino funerario', category: 'funerario', icon: 'scroll' },
  { id: 'coffin', name: 'Ataúd sencillo', category: 'funerario', icon: 'coffin' },
  { id: 'gravestone', name: 'Lápida', category: 'funerario', icon: 'grave' },
];
