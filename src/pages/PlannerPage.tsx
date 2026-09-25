import { useMemo } from 'react';
import { ItemChip } from '../components/ItemChip';
import { Panel } from '../components/Panel';
import { PixelIcon } from '../components/PixelIcon';
import { dayById, isAvailableOn, itemById, recipeById, recipes, sellersOf } from '../data';
import { computeRequirements } from '../lib/planner';
import { go } from '../lib/router';
import { useLocalStorage } from '../lib/useLocalStorage';
import { useAppState } from '../state';

export function PlannerPage() {
  const { plan, setCount, clearPlan, owned, setOwned, today } = useAppState();
  const [deep, setDeep] = useLocalStorage('gk2.deep', true);
  const { materials, steps } = useMemo(() => computeRequirements(plan, recipes, deep), [plan, deep]);

  const entries = Object.entries(plan);
  const rows = Object.entries(materials).sort(([a], [b]) =>
    (itemById.get(a)?.name ?? a).localeCompare(itemById.get(b)?.name ?? b, 'es'),
  );
  const missingCount = rows.filter(([id, qty]) => (owned[id] ?? 0) < qty).length;

  if (entries.length === 0) {
    return (
      <Panel title="Qué necesito" className="empty-state">
        <PixelIcon name="sack" size={64} />
        <p>Tu saco está vacío. Añade recetas desde el recetario para calcular los materiales.</p>
        <button className="btn primary" onClick={() => go('recetas')}>
          Ir al recetario →
        </button>
      </Panel>
    );
  }

  return (
    <div className="split">
      <Panel title="Plan de trabajo" className="sidebar">
        <ul className="list">
          {entries.map(([id, count]) => {
            const r = recipeById.get(id);
            const item = r && itemById.get(r.output);
            return (
              <li key={id} className="plan-row">
                <button className="list-item" onClick={() => go('recetas', id)}>
                  <PixelIcon name={item?.icon ?? 'skull'} size={32} />
                  <span>
                    {item?.name ?? id}
                    <small>{r?.station}</small>
                  </span>
                </button>
                <div className="stepper">
                  <button className="btn small" onClick={() => setCount(id, count - 1)} aria-label="Menos">−</button>
                  <span>{count}</span>
                  <button className="btn small" onClick={() => setCount(id, count + 1)} aria-label="Más">+</button>
                </div>
              </li>
            );
          })}
        </ul>
        <label className="toggle">
          <input type="checkbox" checked={deep} onChange={(e) => setDeep(e.target.checked)} />
          Desglosar hasta materias primas
        </label>
        <button className="btn danger" onClick={clearPlan}>
          × Vaciar plan
        </button>
      </Panel>

      <Panel variant="parchment" className="detail">
        <h1>Materiales</h1>
        <p className="meta">
          {missingCount === 0 ? '✓ Tienes todo lo necesario.' : `Te faltan ${missingCount} de ${rows.length} materiales.`}
        </p>
        <table className="px-table">
          <thead>
            <tr>
              <th>Material</th>
              <th>Necesito</th>
              <th>Tengo</th>
              <th>Faltan</th>
              <th>Dónde conseguirlo</th>
            </tr>
          </thead>
          <tbody>
            {rows.map(([id, qty]) => {
              const have = owned[id] ?? 0;
              const missing = Math.max(0, qty - have);
              const sellers = sellersOf(id);
              return (
                <tr key={id} className={missing === 0 ? 'done' : ''}>
                  <td><ItemChip itemId={id} /></td>
                  <td className="num">{qty}</td>
                  <td>
                    <input
                      className="px-input num-input"
                      type="number"
                      min={0}
                      value={have}
                      onChange={(e) => setOwned(id, Number(e.target.value) || 0)}
                    />
                  </td>
                  <td className="num">{missing === 0 ? '✓' : missing}</td>
                  <td className="where">
                    {itemById.get(id)?.sources?.map((s) => <div key={s}>{s}</div>)}
                    {sellers.map((c) => (
                      <button
                        key={c.id}
                        className={`seller ${isAvailableOn(c, today) ? 'today' : ''}`}
                        onClick={() => go('personajes', c.id)}
                        title={isAvailableOn(c, today) ? 'Está disponible hoy' : undefined}
                      >
                        {c.name} ({c.days.length ? c.days.map((d) => dayById.get(d)?.short).join(', ') : 'todos los días'})
                      </button>
                    ))}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>

        {deep && steps.length > 0 && (
          <>
            <h3>Orden de fabricación</h3>
            <ol className="steps">
              {steps.map((s) => {
                const r = recipeById.get(s.recipeId)!;
                return (
                  <li key={s.recipeId}>
                    Fabrica <strong>{s.crafts}×</strong> {itemById.get(r.output)?.name} en <em>{r.station}</em>{' '}
                    <span className="hint">(→ {s.crafts * r.outputQty} uds.)</span>
                  </li>
                );
              })}
              <li>Por último, las recetas de tu plan.</li>
            </ol>
          </>
        )}
      </Panel>
    </div>
  );
}
