import { palette, sprites, type IconName } from './icons';

interface Props {
  name: IconName;
  /** tamaño en px; usa múltiplos de 8 para que se vea nítido */
  size?: number;
  title?: string;
}

export function PixelIcon({ name, size = 24, title }: Props) {
  const rows = sprites[name];
  return (
    <svg
      className="pixel-icon"
      width={size}
      height={size}
      viewBox="0 0 8 8"
      shapeRendering="crispEdges"
      role={title ? 'img' : undefined}
      aria-hidden={title ? undefined : true}
    >
      {title && <title>{title}</title>}
      {rows.flatMap((row, y) =>
        [...row].map((ch, x) =>
          ch === '.' ? null : <rect key={`${x}-${y}`} x={x} y={y} width={1} height={1} fill={palette[ch]} />,
        ),
      )}
    </svg>
  );
}
