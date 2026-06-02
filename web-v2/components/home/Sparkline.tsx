'use client';

interface SparklineProps {
  data: number[];
  width?: number;
  height?: number;
  color?: string;
  strokeWidth?: number;
  className?: string;
}

/**
 * Tiny inline SVG sparkline used in the hero stat cards (the little red
 * upward trend lines in the design).
 */
export default function Sparkline({
  data,
  width = 72,
  height = 28,
  color = '#FF0000',
  strokeWidth = 2,
  className = '',
}: SparklineProps) {
  if (!data || data.length < 2) return null;

  const min = Math.min(...data);
  const max = Math.max(...data);
  const range = max - min || 1;
  const stepX = width / (data.length - 1);

  const points = data.map((value, i) => {
    const x = i * stepX;
    const y = height - ((value - min) / range) * (height - strokeWidth) - strokeWidth / 2;
    return [x, y] as const;
  });

  const linePath = points.map(([x, y]) => `${x.toFixed(2)},${y.toFixed(2)}`).join(' ');
  const areaPath =
    `M ${points[0][0].toFixed(2)},${height} ` +
    points.map(([x, y]) => `L ${x.toFixed(2)},${y.toFixed(2)}`).join(' ') +
    ` L ${width},${height} Z`;

  const gradId = `spark-${color.replace('#', '')}-${data.length}`;

  return (
    <svg
      width={width}
      height={height}
      viewBox={`0 0 ${width} ${height}`}
      fill="none"
      className={className}
      aria-hidden="true"
    >
      <defs>
        <linearGradient id={gradId} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={color} stopOpacity="0.18" />
          <stop offset="100%" stopColor={color} stopOpacity="0" />
        </linearGradient>
      </defs>
      <path d={areaPath} fill={`url(#${gradId})`} />
      <polyline
        points={linePath}
        stroke={color}
        strokeWidth={strokeWidth}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}
