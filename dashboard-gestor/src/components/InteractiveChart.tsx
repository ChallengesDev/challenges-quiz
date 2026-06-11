import React, { useState } from 'react';

interface ChartDataPoint {
  label: string;
  value: number;
}

interface InteractiveChartProps {
  type: 'line' | 'bar' | 'doughnut';
  data: ChartDataPoint[];
  title?: string;
  height?: number;
  color?: string;
  color2?: string;
  suffix?: string;
}

export const InteractiveChart: React.FC<InteractiveChartProps> = ({
  type,
  data,
  title,
  height = 220,
  color = 'var(--color-primary)',
  color2 = 'var(--color-accent)',
  suffix = ''
}) => {
  const [hoveredIndex, setHoveredIndex] = useState<number | null>(null);
  const [tooltipPos, setTooltipPos] = useState({ x: 0, y: 0 });

  if (!data || data.length === 0) {
    return (
      <div style={{
        height,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        color: 'var(--text-muted)'
      }}>
        Sem dados para exibir
      </div>
    );
  }

  const values = data.map(d => d.value);
  const maxValue = Math.max(...values, 10);
  const minValue = 0;

  // Render Line Chart
  const renderLineChart = () => {
    const padding = 40;
    const chartWidth = 500;
    const chartHeight = height;
    const usableWidth = chartWidth - padding * 2;
    const usableHeight = chartHeight - padding * 2;

    const points = data.map((d, index) => {
      const x = padding + (index / (data.length - 1)) * usableWidth;
      const normalizedY = (d.value - minValue) / (maxValue - minValue);
      const y = padding + (1 - normalizedY) * usableHeight;
      return { x, y, ...d };
    });

    const pathData = points.reduce((acc, p, index) => {
      return acc + (index === 0 ? `M ${p.x} ${p.y}` : ` L ${p.x} ${p.y}`);
    }, '');

    const areaData = pathData + ` L ${points[points.length - 1].x} ${chartHeight - padding} L ${points[0].x} ${chartHeight - padding} Z`;

    return (
      <svg viewBox={`0 0 ${chartWidth} ${chartHeight}`} width="100%" height={chartHeight} style={{ overflow: 'visible' }}>
        <defs>
          <linearGradient id="lineGrad" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={color} stopOpacity="0.4" />
            <stop offset="100%" stopColor={color} stopOpacity="0.0" />
          </linearGradient>
          <filter id="glow" x="-20%" y="-20%" width="140%" height="140%">
            <feGaussianBlur stdDeviation="4" result="blur" />
            <feComposite in="SourceGraphic" in2="blur" operator="over" />
          </filter>
        </defs>

        {/* Gridlines */}
        {[0, 0.25, 0.5, 0.75, 1].map((ratio, idx) => {
          const y = padding + ratio * usableHeight;
          const labelVal = Math.round(maxValue - ratio * (maxValue - minValue));
          return (
            <g key={idx}>
              <line
                x1={padding}
                y1={y}
                x2={chartWidth - padding}
                y2={y}
                stroke="var(--border-color)"
                strokeWidth="1"
                strokeDasharray="4 4"
              />
              <text
                x={padding - 10}
                y={y + 4}
                fill="var(--text-muted)"
                fontSize="10"
                textAnchor="end"
                fontFamily="var(--font-sans)"
              >
                {labelVal}
              </text>
            </g>
          );
        })}

        {/* Area Gradient Under Curve */}
        <path d={areaData} fill="url(#lineGrad)" />

        {/* Stroke Line */}
        <path
          d={pathData}
          fill="none"
          stroke={color}
          strokeWidth="3"
          filter="url(#glow)"
          strokeLinecap="round"
          strokeLinejoin="round"
        />

        {/* Interactive Circles / Nodes */}
        {points.map((p, index) => (
          <g key={index}>
            <circle
              cx={p.x}
              cy={p.y}
              r={hoveredIndex === index ? 6 : 4}
              fill={hoveredIndex === index ? color : 'var(--bg-card)'}
              stroke={color}
              strokeWidth="2"
              style={{ cursor: 'pointer', transition: 'all 0.1s ease' }}
              onMouseEnter={() => {
                setHoveredIndex(index);
                setTooltipPos({ x: p.x, y: p.y - 12 });
              }}
              onMouseLeave={() => setHoveredIndex(null)}
            />
            {/* X Labels */}
            {index % Math.ceil(data.length / 5) === 0 && (
              <text
                x={p.x}
                y={chartHeight - padding + 18}
                fill="var(--text-muted)"
                fontSize="9"
                textAnchor="middle"
                fontFamily="var(--font-sans)"
              >
                {p.label}
              </text>
            )}
          </g>
        ))}

        {/* Hover Tooltip */}
        {hoveredIndex !== null && (
          <g transform={`translate(${tooltipPos.x}, ${tooltipPos.y})`}>
            <rect
              x="-60"
              y="-32"
              width="120"
              height="24"
              rx="4"
              fill="var(--bg-sidebar)"
              stroke="var(--border-color)"
              strokeWidth="1"
            />
            <text
              x="0"
              y="-16"
              fill="var(--text-main)"
              fontSize="11"
              fontWeight="bold"
              textAnchor="middle"
              alignmentBaseline="middle"
              fontFamily="var(--font-sans)"
            >
              {points[hoveredIndex].label}: {points[hoveredIndex].value}{suffix}
            </text>
          </g>
        )}
      </svg>
    );
  };

  // Render Bar Chart
  const renderBarChart = () => {
    const padding = 40;
    const chartWidth = 500;
    const chartHeight = height;
    const usableWidth = chartWidth - padding * 2;
    const usableHeight = chartHeight - padding * 2;

    const barWidth = Math.max(10, (usableWidth / data.length) * 0.6);
    const gap = (usableWidth - barWidth * data.length) / (data.length - 1 || 1);

    return (
      <svg viewBox={`0 0 ${chartWidth} ${chartHeight}`} width="100%" height={chartHeight} style={{ overflow: 'visible' }}>
        <defs>
          <linearGradient id="barGrad" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={color} />
            <stop offset="100%" stopColor={color2} />
          </linearGradient>
        </defs>

        {/* Gridlines */}
        {[0, 0.25, 0.5, 0.75, 1].map((ratio, idx) => {
          const y = padding + ratio * usableHeight;
          const labelVal = Math.round(maxValue - ratio * (maxValue - minValue));
          return (
            <g key={idx}>
              <line
                x1={padding}
                y1={y}
                x2={chartWidth - padding}
                y2={y}
                stroke="var(--border-color)"
                strokeWidth="1"
                strokeDasharray="4 4"
              />
              <text
                x={padding - 10}
                y={y + 4}
                fill="var(--text-muted)"
                fontSize="10"
                textAnchor="end"
                fontFamily="var(--font-sans)"
              >
                {labelVal}
              </text>
            </g>
          );
        })}

        {/* Bars */}
        {data.map((d, index) => {
          const x = padding + index * (barWidth + gap);
          const normalizedY = d.value / maxValue;
          const barHeight = usableHeight * normalizedY;
          const y = chartHeight - padding - barHeight;

          return (
            <g key={index}>
              <rect
                x={x}
                y={y}
                width={barWidth}
                height={barHeight}
                rx="3"
                fill={hoveredIndex === index ? 'var(--color-cyan)' : 'url(#barGrad)'}
                style={{ cursor: 'pointer', transition: 'fill 0.2s ease' }}
                onMouseEnter={() => {
                  setHoveredIndex(index);
                  setTooltipPos({ x: x + barWidth / 2, y: y - 10 });
                }}
                onMouseLeave={() => setHoveredIndex(null)}
              />
              {/* X Labels */}
              {index % Math.ceil(data.length / 8) === 0 && (
                <text
                  x={x + barWidth / 2}
                  y={chartHeight - padding + 18}
                  fill="var(--text-muted)"
                  fontSize="9"
                  textAnchor="middle"
                  fontFamily="var(--font-sans)"
                >
                  {d.label}
                </text>
              )}
            </g>
          );
        })}

        {/* Tooltip */}
        {hoveredIndex !== null && (
          <g transform={`translate(${tooltipPos.x}, ${tooltipPos.y})`}>
            <rect
              x="-60"
              y="-32"
              width="120"
              height="24"
              rx="4"
              fill="var(--bg-sidebar)"
              stroke="var(--border-color)"
              strokeWidth="1"
            />
            <text
              x="0"
              y="-16"
              fill="var(--text-main)"
              fontSize="11"
              fontWeight="bold"
              textAnchor="middle"
              alignmentBaseline="middle"
              fontFamily="var(--font-sans)"
            >
              {data[hoveredIndex].label}: {data[hoveredIndex].value}{suffix}
            </text>
          </g>
        )}
      </svg>
    );
  };

  // Render Doughnut Chart
  const renderDoughnutChart = () => {
    const size = height;
    const center = size / 2;
    const radius = size * 0.35;
    const strokeWidth = size * 0.12;
    const total = values.reduce((a, b) => a + b, 0);

    let accumulatedAngle = -90; // Start at top

    const segments = data.map((d, index) => {
      const percentage = total > 0 ? d.value / total : 0;
      const angle = percentage * 360;
      const startAngle = accumulatedAngle;
      const endAngle = accumulatedAngle + angle;
      accumulatedAngle += angle;

      // Calculate path coords
      const rad = Math.PI / 180;
      const x1 = center + radius * Math.cos(startAngle * rad);
      const y1 = center + radius * Math.sin(startAngle * rad);
      const x2 = center + radius * Math.cos(endAngle * rad);
      const y2 = center + radius * Math.sin(endAngle * rad);
      const largeArc = angle > 180 ? 1 : 0;

      const pathData = `M ${x1} ${y1} A ${radius} ${radius} 0 ${largeArc} 1 ${x2} ${y2}`;

      // Colors mapping
      const colorsList = [
        'var(--color-primary)',
        'var(--color-accent)',
        'var(--color-cyan)',
        'var(--status-success)',
        'var(--status-warning)',
        'var(--status-error)'
      ];
      const segmentColor = colorsList[index % colorsList.length];

      return {
        pathData,
        color: segmentColor,
        percentage,
        ...d
      };
    });

    return (
      <div style={{ display: 'flex', alignItems: 'center', gap: '24px', flexWrap: 'wrap', justifyContent: 'center' }}>
        <svg width={size} height={size} style={{ overflow: 'visible' }}>
          {segments.map((seg, index) => (
            <path
              key={index}
              d={seg.pathData}
              fill="none"
              stroke={hoveredIndex === index ? '#fff' : seg.color}
              strokeWidth={hoveredIndex === index ? strokeWidth + 3 : strokeWidth}
              style={{ cursor: 'pointer', transition: 'stroke-width 0.2s, stroke 0.2s' }}
              onMouseEnter={() => setHoveredIndex(index)}
              onMouseLeave={() => setHoveredIndex(null)}
            />
          ))}
          {/* Central Hole */}
          <circle
            cx={center}
            cy={center}
            r={radius - strokeWidth / 2 - 2}
            fill="var(--bg-card)"
          />
          {/* Label inside Doughnut */}
          <text
            x={center}
            y={center - 4}
            textAnchor="middle"
            fill="var(--text-white)"
            fontSize="18"
            fontWeight="bold"
            fontFamily="var(--font-heading)"
          >
            {hoveredIndex !== null
              ? `${Math.round(segments[hoveredIndex].percentage * 100)}%`
              : `${total}`}
          </text>
          <text
            x={center}
            y={center + 14}
            textAnchor="middle"
            fill="var(--text-muted)"
            fontSize="10"
            letterSpacing="0.05em"
            fontFamily="var(--font-sans)"
            style={{ textTransform: 'uppercase' }}
          >
            {hoveredIndex !== null
              ? segments[hoveredIndex].label
              : 'Total'}
          </text>
        </svg>

        {/* Legend */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', minWidth: '150px' }}>
          {segments.map((seg, index) => (
            <div
              key={index}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                fontSize: '13px',
                cursor: 'pointer',
                opacity: hoveredIndex === null || hoveredIndex === index ? 1 : 0.4,
                transition: 'opacity 0.2s'
              }}
              onMouseEnter={() => setHoveredIndex(index)}
              onMouseLeave={() => setHoveredIndex(null)}
            >
              <div style={{ width: '12px', height: '12px', borderRadius: '3px', backgroundColor: seg.color }}></div>
              <span style={{ color: 'var(--text-muted)' }}>{seg.label}</span>
              <span style={{ marginLeft: 'auto', fontWeight: 'bold', color: 'var(--text-main)' }}>
                {seg.value}{suffix}
              </span>
            </div>
          ))}
        </div>
      </div>
    );
  };

  return (
    <div className="card" style={{ padding: '20px', display: 'flex', flexDirection: 'column', gap: '16px' }}>
      {title && (
        <h4 style={{
          fontFamily: 'var(--font-heading)',
          fontSize: '15px',
          fontWeight: 600,
          color: 'var(--text-white)',
          borderBottom: '1px solid var(--border-color)',
          paddingBottom: '10px'
        }}>
          {title}
        </h4>
      )}
      <div style={{ flexGrow: 1, position: 'relative' }}>
        {type === 'line' && renderLineChart()}
        {type === 'bar' && renderBarChart()}
        {type === 'doughnut' && renderDoughnutChart()}
      </div>
    </div>
  );
};
