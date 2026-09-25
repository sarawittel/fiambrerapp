import { createContext, useContext, type ReactNode } from 'react';
import { days } from './data';
import type { Plan } from './lib/planner';
import { useLocalStorage } from './lib/useLocalStorage';

interface AppState {
  plan: Plan;
  setCount: (recipeId: string, count: number) => void;
  addToPlan: (recipeId: string) => void;
  clearPlan: () => void;
  owned: Record<string, number>;
  setOwned: (itemId: string, qty: number) => void;
  today: string;
  setToday: (dayId: string) => void;
}

const Ctx = createContext<AppState | null>(null);

export function AppStateProvider({ children }: { children: ReactNode }) {
  const [plan, setPlan] = useLocalStorage<Plan>('gk2.plan', {});
  const [owned, setOwnedMap] = useLocalStorage<Record<string, number>>('gk2.owned', {});
  const [today, setToday] = useLocalStorage('gk2.today', days[0].id);

  const setCount = (recipeId: string, count: number) =>
    setPlan((p) => {
      const next = { ...p };
      if (count > 0) next[recipeId] = count;
      else delete next[recipeId];
      return next;
    });

  const value: AppState = {
    plan,
    setCount,
    addToPlan: (id) => setCount(id, (plan[id] ?? 0) + 1),
    clearPlan: () => setPlan({}),
    owned,
    setOwned: (itemId, qty) => setOwnedMap((o) => ({ ...o, [itemId]: Math.max(0, qty) })),
    today: days.some((d) => d.id === today) ? today : days[0].id,
    setToday,
  };
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useAppState() {
  const ctx = useContext(Ctx);
  if (!ctx) throw new Error('useAppState debe usarse dentro de AppStateProvider');
  return ctx;
}
