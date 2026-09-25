import type { ReactNode } from 'react';

interface Props {
  title?: ReactNode;
  variant?: 'wood' | 'parchment';
  className?: string;
  children: ReactNode;
}

export function Panel({ title, variant = 'wood', className = '', children }: Props) {
  return (
    <section className={`panel panel-${variant} ${className}`}>
      {title && <h2 className="panel-title">{title}</h2>}
      {children}
    </section>
  );
}
