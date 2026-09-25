import { useMemo, useState } from 'react';
import { ItemChip } from '../components/ItemChip';
import { Panel } from '../components/Panel';
import { PixelIcon } from '../components/PixelIcon';
import { itemById, recipeById, recipeForItem, recipes, recipesUsing, sellersOf, stations, type Recipe } from '../data';
import { go } from '../lib/router';
import { normalize } from '../lib/text';
import { useAppState } from '../state';

export function RecipesPage({ selectedId }: { selectedId?: string }) {
  const [query, setQuery] = useState('');
  const [station, setStation] = useState('');

  const filtered = useMemo(() => {
    const q = normalize(query.trim());
    return recipes.filter((r) => {
      if (station && r.station !== station) return false;
      if (!q) return true;
      const names = [r.output, ...r.ingredients.map((i) => i.item)].map((id) => itemById.get(id)?.name ?? id);
      return names.some((n) => normalize(n).includes(q));
    });
  }, [query, station]);

  const selected = (selectedId && recipeById.get(selectedId)) || filtered[0];

  return (
    <div className="split">
      <Panel title="Recetario" className="sidebar">
        <input
          className="px-input"
          placeholder="Buscar objeto o ingrediente…"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
        <select className="px-input" value={station} onChange={(e) => setStation(e.target.value)}>
          <option value="">Todas las estaciones</option>
          {stations.map((s) => (
            <option key={s}>{s}</option>
          ))}
        </select>
        <ul className="list">
          {filtered.map((r) => {
            const item = itemById.get(r.output);
            return (
              <li key={r.id}>
                <button
                  className={`list-item ${selected?.id === r.id ? 'active' : ''}`}
                  onClick={() => go('recetas', r.id)}
                >
                  <PixelIcon name={item?.icon ?? 'skull'} size={32} />
                  <span>
                    {item?.name ?? r.output}
                    <small>{r.station}</small>
                  </span>
                </button>
              </li>
            );
          })}
          {filtered.length === 0 && <li className="empty">Nada por aquí… solo polvo y huesos.</li>}
        </ul>
      </Panel>
      {selected && <RecipeDetail recipe={selected} />}
    </div>
  );
}

function RecipeDetail({ recipe }: { recipe: Recipe }) {
  const { plan, addToPlan } = useAppState();
  const item = itemById.get(recipe.output);
  const usedIn = recipesUsing(recipe.output);
  const inPlan = plan[recipe.id] ?? 0;

  return (
    <Panel variant="parchment" className="detail">
      <header className="detail-head">
        <div className="icon-frame">
          <PixelIcon name={item?.icon ?? 'skull'} size={64} />
        </div>
        <div>
          <h1>{item?.name ?? recipe.output}</h1>
          <p className="meta">
            <span className="tag">{recipe.station}</span>
            <span className="tag">Produce ×{recipe.outputQty}</span>
            {recipe.time !== undefined && <span className="tag">{recipe.time} h</span>}
          </p>
        </div>
      </header>

      {item?.description && <p className="flavor">«{item.description}»</p>}

      <h3>Ingredientes</h3>
      <ul className="ingredients">
        {recipe.ingredients.map((ing) => {
          const craftable = recipeForItem.has(ing.item);
          const sources = itemById.get(ing.item)?.sources ?? [];
          const sellers = sellersOf(ing.item);
          return (
            <li key={ing.item}>
              <ItemChip itemId={ing.item} qty={ing.qty} />
              <span className="hint">
                {craftable
                  ? 'Fabricable'
                  : [...sources, ...sellers.map((s) => `Lo vende: ${s.name}`)].join(' · ') || 'Origen desconocido'}
              </span>
            </li>
          );
        })}
      </ul>

      {recipe.notes && <p className="note">{recipe.notes}</p>}

      {usedIn.length > 0 && (
        <>
          <h3>Se usa en</h3>
          <div className="chips">
            {usedIn.map((r) => (
              <ItemChip key={r.id} itemId={r.output} />
            ))}
          </div>
        </>
      )}

      <div className="actions">
        <button className="btn primary" onClick={() => addToPlan(recipe.id)}>
          + Añadir al plan {inPlan > 0 && `(${inPlan})`}
        </button>
        <button className="btn" onClick={() => go('necesito')}>
          Qué necesito →
        </button>
      </div>
    </Panel>
  );
}
