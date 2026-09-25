import { useState } from 'react';
import { DayBadges } from '../components/DayBadges';
import { ItemChip } from '../components/ItemChip';
import { Panel } from '../components/Panel';
import { PixelIcon } from '../components/PixelIcon';
import { characterById, characters, days, isAvailableOn } from '../data';
import { go } from '../lib/router';
import { useAppState } from '../state';

export function CharactersPage({ selectedId }: { selectedId?: string }) {
  const { today } = useAppState();
  const [dayFilter, setDayFilter] = useState('');
  const list = dayFilter ? characters.filter((c) => isAvailableOn(c, dayFilter)) : characters;
  const selected = selectedId ? characterById.get(selectedId) : undefined;

  return (
    <div className="stack">
      <Panel title="Personajes">
        <div className="chips">
          <button className={`btn small ${dayFilter === '' ? 'primary' : ''}`} onClick={() => setDayFilter('')}>
            Todos
          </button>
          {days.map((d) => (
            <button
              key={d.id}
              className={`btn small ${dayFilter === d.id ? 'primary' : ''}`}
              onClick={() => setDayFilter(d.id)}
            >
              <PixelIcon name={d.icon} size={16} /> {d.short}
            </button>
          ))}
        </div>
        <div className="card-grid">
          {list.map((c) => (
            <button
              key={c.id}
              className={`card ${selected?.id === c.id ? 'active' : ''}`}
              onClick={() => go('personajes', c.id)}
            >
              <div className="icon-frame">
                <PixelIcon name={c.icon} size={48} />
              </div>
              <strong>{c.name}</strong>
              <small>{c.title}</small>
              {isAvailableOn(c, today) && <span className="tag live">Hoy aquí</span>}
            </button>
          ))}
        </div>
      </Panel>

      {selected && (
        <Panel variant="parchment" className="detail">
          <header className="detail-head">
            <div className="icon-frame">
              <PixelIcon name={selected.icon} size={64} />
            </div>
            <div>
              <h1>{selected.name}</h1>
              <p className="meta">
                <span className="tag">{selected.title}</span>
                <span className="tag">{selected.location}</span>
              </p>
            </div>
          </header>
          <h3>Días de visita</h3>
          <DayBadges active={selected.days} />
          {selected.sells?.length ? (
            <>
              <h3>Vende</h3>
              <div className="chips">{selected.sells.map((i) => <ItemChip key={i} itemId={i} />)}</div>
            </>
          ) : null}
          {selected.buys?.length ? (
            <>
              <h3>Compra</h3>
              <div className="chips">{selected.buys.map((i) => <ItemChip key={i} itemId={i} />)}</div>
            </>
          ) : null}
          {selected.notes && <p className="note">{selected.notes}</p>}
        </Panel>
      )}
    </div>
  );
}
