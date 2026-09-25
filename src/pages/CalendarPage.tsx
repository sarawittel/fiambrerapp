import type { CSSProperties } from 'react';
import { Panel } from '../components/Panel';
import { PixelIcon } from '../components/PixelIcon';
import { characters, days, isAvailableOn } from '../data';
import { go } from '../lib/router';
import { useAppState } from '../state';

export function CalendarPage() {
  const { today, setToday } = useAppState();
  const idx = days.findIndex((d) => d.id === today);
  const day = days[idx];
  const tomorrow = days[(idx + 1) % days.length];
  const present = characters.filter((c) => isAvailableOn(c, today));
  const arriving = characters.filter((c) => isAvailableOn(c, tomorrow.id) && !isAvailableOn(c, today));

  return (
    <div className="stack">
      <Panel title="La semana">
        <div className="week">
          {days.map((d) => (
            <button
              key={d.id}
              className={`day-tile ${d.id === today ? 'active' : ''}`}
              style={{ '--day-color': d.color } as CSSProperties}
              onClick={() => setToday(d.id)}
            >
              <PixelIcon name={d.icon} size={40} />
              <span>{d.short}</span>
            </button>
          ))}
        </div>
        <div className="actions">
          <button className="btn primary" onClick={() => setToday(tomorrow.id)}>
            Dormir hasta el día siguiente →
          </button>
        </div>
      </Panel>

      <div className="split even">
        <Panel variant="parchment" title={`Hoy · ${day.name}`}>
          <CharacterList list={present} empty="Nadie a la vista. Buen día para cavar." />
        </Panel>
        <Panel variant="parchment" title={`Mañana llegan · ${tomorrow.short}`}>
          <CharacterList list={arriving} empty="Nadie nuevo mañana." />
        </Panel>
      </div>

      <Panel title="Quién está cada día">
        <div className="table-scroll">
          <table className="px-table grid">
            <thead>
              <tr>
                <th>Personaje</th>
                {days.map((d) => (
                  <th key={d.id} className={d.id === today ? 'today' : ''} title={d.name}>
                    <PixelIcon name={d.icon} size={16} />
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {characters.map((c) => (
                <tr key={c.id} onClick={() => go('personajes', c.id)} className="clickable">
                  <td>{c.name}</td>
                  {days.map((d) => (
                    <td key={d.id} className={`cell ${d.id === today ? 'today' : ''}`}>
                      {isAvailableOn(c, d.id) ? '●' : ''}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Panel>
    </div>
  );
}

function CharacterList({ list, empty }: { list: typeof characters; empty: string }) {
  if (list.length === 0) return <p className="empty">{empty}</p>;
  return (
    <ul className="list">
      {list.map((c) => (
        <li key={c.id}>
          <button className="list-item" onClick={() => go('personajes', c.id)}>
            <PixelIcon name={c.icon} size={32} />
            <span>
              {c.name}
              <small>{c.location}</small>
            </span>
          </button>
        </li>
      ))}
    </ul>
  );
}
