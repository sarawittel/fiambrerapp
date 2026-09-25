import type { IconName } from '../components/icons';

export type ItemCategory = 'material' | 'comida' | 'alquimia' | 'funerario' | 'herramienta';

export interface Item {
  id: string;
  name: string;
  category: ItemCategory;
  icon: IconName;
  /** Dónde se obtiene si no se fabrica (texto libre). */
  sources?: string[];
  description?: string;
}

export interface Ingredient {
  item: string;
  qty: number;
}

export interface Recipe {
  id: string;
  /** id del objeto que produce */
  output: string;
  /** unidades producidas por cada fabricación */
  outputQty: number;
  station: string;
  ingredients: Ingredient[];
  /** duración aproximada en horas de juego */
  time?: number;
  notes?: string;
}

export interface Day {
  id: string;
  name: string;
  short: string;
  icon: IconName;
  color: string;
}

export interface Character {
  id: string;
  name: string;
  title: string;
  location: string;
  icon: IconName;
  /** ids de día; vacío = todos los días */
  days: string[];
  sells?: string[];
  buys?: string[];
  notes?: string;
}
