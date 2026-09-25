import { days } from '../data';
import { useAppState } from '../state';
import { PixelIcon } from './PixelIcon';

/** Tira de la semana marcando los días en que aparece alguien. */
export function DayBadges({ active }: { active: string[] }) {
  const { today } = useAppState();
  const all = active.length === 0;
  return (
    <div className="day-badges">
      {days.map((d) => {
        const on = all || active.includes(d.id);
        return (
          <span
            key={d.id}
            className={`day-badge ${on ? 'on' : 'off'} ${d.id === today ? 'today' : ''}`}
            style={on ? { borderColor: d.color } : undefined}
            title={d.name}
          >
            <PixelIcon name={d.icon} size={16} />
            {d.short}
          </span>
        );
      })}
    </div>
  );
}
