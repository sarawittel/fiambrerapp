import { itemById, recipeForItem } from '../data';
import { go } from '../lib/router';
import { PixelIcon } from './PixelIcon';

interface Props {
  itemId: string;
  qty?: number;
}

/** Objeto con icono; si es fabricable, enlaza a su receta. */
export function ItemChip({ itemId, qty }: Props) {
  const item = itemById.get(itemId);
  const recipe = recipeForItem.get(itemId);
  const label = item?.name ?? itemId;
  const content = (
    <>
      <PixelIcon name={item?.icon ?? 'skull'} size={24} />
      <span>{label}</span>
      {qty !== undefined && <span className="qty">×{qty}</span>}
    </>
  );
  return recipe ? (
    <button className="chip chip-link" onClick={() => go('recetas', recipe.id)} title="Ver receta">
      {content}
    </button>
  ) : (
    <span className="chip">{content}</span>
  );
}
