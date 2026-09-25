import { useEffect, useState } from 'react';

export const pages = ['recetas', 'necesito', 'calendario', 'personajes'] as const;
export type Page = (typeof pages)[number];

export interface Route {
  page: Page;
  param?: string;
}

function parse(hash: string): Route {
  const [, page, param] = hash.replace(/^#/, '').split('/');
  return {
    page: (pages as readonly string[]).includes(page) ? (page as Page) : 'recetas',
    param: param ? decodeURIComponent(param) : undefined,
  };
}

/** Enrutado por hash (#/recetas/r_pan) para poder compartir enlaces sin servidor. */
export function useRoute(): Route {
  const [route, setRoute] = useState(() => parse(window.location.hash));
  useEffect(() => {
    const onChange = () => setRoute(parse(window.location.hash));
    window.addEventListener('hashchange', onChange);
    return () => window.removeEventListener('hashchange', onChange);
  }, []);
  return route;
}

export function go(page: Page, param?: string) {
  window.location.hash = `/${page}${param ? `/${encodeURIComponent(param)}` : ''}`;
}
