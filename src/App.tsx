import { PixelIcon } from './components/PixelIcon';
import type { IconName } from './components/icons';
import { dayById } from './data';
import { go, useRoute, type Page } from './lib/router';
import { CalendarPage } from './pages/CalendarPage';
import { CharactersPage } from './pages/CharactersPage';
import { PlannerPage } from './pages/PlannerPage';
import { RecipesPage } from './pages/RecipesPage';
import { useAppState } from './state';

const tabs: { page: Page; label: string; icon: IconName }[] = [
  { page: 'recetas', label: 'Recetas', icon: 'cauldron' },
  { page: 'necesito', label: 'Qué necesito', icon: 'sack' },
  { page: 'calendario', label: 'Calendario', icon: 'moon' },
  { page: 'personajes', label: 'Personajes', icon: 'person' },
];

export function App() {
  const { page, param } = useRoute();
  const { today, plan } = useAppState();
  const day = dayById.get(today)!;
  const planSize = Object.values(plan).reduce((a, b) => a + b, 0);

  return (
    <div className="app">
      <header className="topbar">
        <div className="brand">
          <PixelIcon name="skull" size={40} />
          <div>
            <span className="brand-title">Guía del Guardián</span>
            <span className="brand-sub">Graveyard Keeper 2</span>
          </div>
        </div>
        <button className="today-badge" onClick={() => go('calendario')} title="Cambiar día">
          <PixelIcon name={day.icon} size={24} />
          Hoy: {day.short}
        </button>
      </header>

      <nav className="tabs">
        {tabs.map((t) => (
          <button key={t.page} className={`tab ${page === t.page ? 'active' : ''}`} onClick={() => go(t.page)}>
            <PixelIcon name={t.icon} size={24} />
            {t.label}
            {t.page === 'necesito' && planSize > 0 && <span className="count">{planSize}</span>}
          </button>
        ))}
      </nav>

      <p className="notice">Datos de ejemplo – edita los archivos de src/data/ con la información real del juego.</p>

      <main>
        {page === 'recetas' && <RecipesPage selectedId={param} />}
        {page === 'necesito' && <PlannerPage />}
        {page === 'calendario' && <CalendarPage />}
        {page === 'personajes' && <CharactersPage selectedId={param} />}
      </main>

      <footer className="footer">Guía no oficial hecha por fans. Graveyard Keeper es marca de sus respectivos propietarios.</footer>
    </div>
  );
}
