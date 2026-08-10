import { useEffect, useMemo, useState } from 'react'
import {
  ResponsiveContainer,
  BarChart,
  Bar,
  LineChart,
  Line,
  PieChart,
  Pie,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  Cell,
} from 'recharts'
import {
  aggregateBy,
  aggregateByPeriod,
  aggregateQuarters,
} from '../utils/analyze'
import { createAxisFormatter, formatWithUnit } from '../utils/format'

const PALETTE = [
  '#2dd4bf', '#38bdf8', '#818cf8', '#f472b6',
  '#fbbf24', '#a3e635', '#fb7185', '#34d399',
]

const RANKING_LIMIT = 15
const DONUT_LIMIT = 8

const tooltipStyle = {
  background: '#111d33',
  border: '1px solid #24324d',
  borderRadius: 8,
  color: '#e2e8f0',
  fontSize: 12,
}

// 좁은 화면에서는 축 레이블 폭을 줄여야 막대가 표시될 공간이 남는다.
function useIsNarrow(breakpoint = 700) {
  const [narrow, setNarrow] = useState(
    typeof window !== 'undefined' ? window.innerWidth < breakpoint : false
  )
  useEffect(() => {
    const onResize = () => setNarrow(window.innerWidth < breakpoint)
    window.addEventListener('resize', onResize)
    return () => window.removeEventListener('resize', onResize)
  }, [breakpoint])
  return narrow
}

function Selector({ value, options, onChange, label }) {
  if (!options || options.length <= 1) return null
  return (
    <select
      className="chart-select"
      value={value}
      onChange={(e) => onChange(e.target.value)}
      aria-label={label}
    >
      {options.map((o) => (
        <option key={o} value={o}>
          {label}: {o}
        </option>
      ))}
    </select>
  )
}

function ChartCard({ title, controls, wide, children }) {
  return (
    <div className={`chart-card${wide ? ' chart-card-wide' : ''}`}>
      <div className="chart-header">
        <div className="chart-title">{title}</div>
        {controls && <div className="chart-controls">{controls}</div>}
      </div>
      {children}
    </div>
  )
}

/** 차원별 세로 막대 — 기준 축과 값을 바꿀 수 있다. */
function CategoryBar({ rows, spec, analysis }) {
  const dimOptions = analysis.groupDims.map((d) => d.name)
  const [dim, setDim] = useState(spec.dimension)
  const [measure, setMeasure] = useState(spec.measure)
  const col = analysis.byName[measure]
  const agg = col?.kind === 'percent' ? 'avg' : 'sum'

  const data = useMemo(
    () => aggregateBy(rows, dim, measure, agg).sort((a, b) => b.value - a.value),
    [rows, dim, measure, agg]
  )
  const axisFormat = useMemo(() => createAxisFormatter(data.map((d) => d.value)), [data])

  return (
    <ChartCard
      title={`${dim}별 ${measure}`}
      controls={
        <>
          <Selector value={dim} options={dimOptions} onChange={setDim} label="기준" />
          <Selector value={measure} options={analysis.measureNames} onChange={setMeasure} label="값" />
        </>
      }
    >
      <ResponsiveContainer width="100%" height={260}>
        <BarChart data={data} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" vertical={false} />
          <XAxis dataKey="name" stroke="#94a3b8" fontSize={11} tickLine={false} interval={0} />
          <YAxis stroke="#94a3b8" fontSize={11} tickLine={false} tickFormatter={axisFormat} />
          <Tooltip
            contentStyle={tooltipStyle}
            cursor={{ fill: 'rgba(255,255,255,0.05)' }}
            formatter={(v) => [formatWithUnit(v, col), measure]}
          />
          <Bar dataKey="value" radius={[6, 6, 0, 0]} activeBar={false}>
            {data.map((_, i) => (
              <Cell key={i} fill={PALETTE[i % PALETTE.length]} />
            ))}
          </Bar>
        </BarChart>
      </ResponsiveContainer>
    </ChartCard>
  )
}

/** 기간별 추이 — 분기 컬럼 묶음 또는 날짜/월 컬럼 기반. */
function TrendLine({ rows, spec, analysis }) {
  const isQuarter = spec.type === 'quarter'
  const groupOptions = isQuarter ? spec.groups.map((g) => g.label) : []
  const [group, setGroup] = useState(spec.group)
  const [measure, setMeasure] = useState(spec.measure)

  const activeGroup = isQuarter ? spec.groups.find((g) => g.label === group) : null
  const col = isQuarter
    ? analysis.byName[activeGroup?.columns[0]]
    : analysis.byName[measure]

  const data = useMemo(() => {
    if (isQuarter) return activeGroup ? aggregateQuarters(rows, activeGroup) : []
    return aggregateByPeriod(rows, spec.period, measure)
  }, [rows, isQuarter, activeGroup, spec.period, measure])

  const axisFormat = useMemo(() => createAxisFormatter(data.map((d) => d.value)), [data])
  const title = isQuarter ? `분기별 ${group} 추이` : `${spec.period}별 ${measure} 추이`

  return (
    <ChartCard
      title={title}
      controls={
        isQuarter ? (
          <Selector value={group} options={groupOptions} onChange={setGroup} label="값" />
        ) : (
          <Selector value={measure} options={analysis.measureNames} onChange={setMeasure} label="값" />
        )
      }
    >
      <ResponsiveContainer width="100%" height={260}>
        <LineChart data={data} margin={{ top: 10, right: 14, left: 0, bottom: 0 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" vertical={false} />
          <XAxis
            dataKey="name"
            stroke="#94a3b8"
            fontSize={11}
            tickLine={false}
            interval="preserveStartEnd"
          />
          <YAxis stroke="#94a3b8" fontSize={11} tickLine={false} tickFormatter={axisFormat} />
          <Tooltip
            contentStyle={tooltipStyle}
            formatter={(v) => [formatWithUnit(v, col), isQuarter ? group : measure]}
          />
          <Line
            type="monotone"
            dataKey="value"
            stroke="#38bdf8"
            strokeWidth={3}
            dot={{ r: 4, fill: '#38bdf8' }}
            activeDot={{ r: 6 }}
          />
        </LineChart>
      </ResponsiveContainer>
    </ChartCard>
  )
}

/** 구성비 도넛 — 상위 항목만 남기고 나머지는 기타로 묶는다. */
function CompositionDonut({ rows, spec, analysis }) {
  const dimOptions = analysis.groupDims.map((d) => d.name)
  const [dim, setDim] = useState(spec.dimension)
  const measure = spec.measure
  const col = analysis.byName[measure]

  const data = useMemo(() => {
    const all = aggregateBy(rows, dim, measure, 'sum')
      .filter((d) => d.value > 0)
      .sort((a, b) => b.value - a.value)
    if (all.length <= DONUT_LIMIT) return all
    const head = all.slice(0, DONUT_LIMIT)
    const rest = all.slice(DONUT_LIMIT).reduce((s, d) => s + d.value, 0)
    return rest > 0 ? [...head, { name: '기타', value: rest }] : head
  }, [rows, dim, measure])

  const total = data.reduce((s, d) => s + d.value, 0)

  return (
    <ChartCard
      title={`${dim} 구성비`}
      controls={<Selector value={dim} options={dimOptions} onChange={setDim} label="기준" />}
    >
      <ResponsiveContainer width="100%" height={260}>
        <PieChart>
          <Pie
            data={data}
            dataKey="value"
            nameKey="name"
            innerRadius={52}
            outerRadius={82}
            paddingAngle={2}
            stroke="none"
          >
            {data.map((_, i) => (
              <Cell key={i} fill={PALETTE[i % PALETTE.length]} />
            ))}
          </Pie>
          <Tooltip
            contentStyle={tooltipStyle}
            formatter={(v, name) => [
              `${formatWithUnit(v, col)} (${total ? ((v / total) * 100).toFixed(1) : 0}%)`,
              name,
            ]}
          />
          <Legend
            verticalAlign="bottom"
            height={54}
            iconSize={9}
            wrapperStyle={{ fontSize: 11, color: '#93a3bd' }}
          />
        </PieChart>
      </ResponsiveContainer>
    </ChartCard>
  )
}

/** 상위 N개 항목 가로 막대. */
function RankingBar({ rows, spec, analysis }) {
  const narrow = useIsNarrow()
  const [measure, setMeasure] = useState(spec.measure)
  const dim = spec.dimension
  const col = analysis.byName[measure]
  const agg = col?.kind === 'percent' ? 'avg' : 'sum'

  const all = useMemo(
    () => aggregateBy(rows, dim, measure, agg).sort((a, b) => b.value - a.value),
    [rows, dim, measure, agg]
  )
  const shown = all.slice(0, RANKING_LIMIT)
  const axisFormat = useMemo(() => createAxisFormatter(shown.map((d) => d.value)), [shown])
  const height = Math.max(260, shown.length * 32)
  const title =
    all.length > RANKING_LIMIT
      ? `${dim}별 ${measure} (상위 ${RANKING_LIMIT}개 / 전체 ${all.length}개)`
      : `${dim}별 ${measure}`

  return (
    <ChartCard
      title={title}
      wide
      controls={<Selector value={measure} options={analysis.measureNames} onChange={setMeasure} label="값" />}
    >
      <ResponsiveContainer width="100%" height={height}>
        <BarChart data={shown} layout="vertical" margin={{ top: 10, right: 20, left: 10, bottom: 0 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" horizontal={false} />
          <XAxis type="number" stroke="#94a3b8" fontSize={11} tickLine={false} tickFormatter={axisFormat} />
          <YAxis
            type="category"
            dataKey="name"
            stroke="#94a3b8"
            fontSize={narrow ? 9 : 11}
            width={narrow ? 92 : 200}
            tickLine={false}
            interval={0}
          />
          <Tooltip
            contentStyle={tooltipStyle}
            cursor={{ fill: 'rgba(255,255,255,0.05)' }}
            formatter={(v) => [formatWithUnit(v, col), measure]}
          />
          <Bar dataKey="value" radius={[0, 6, 6, 0]} activeBar={false}>
            {shown.map((_, i) => (
              <Cell key={i} fill={PALETTE[i % PALETTE.length]} />
            ))}
          </Bar>
        </BarChart>
      </ResponsiveContainer>
    </ChartCard>
  )
}

const RENDERERS = {
  bar: CategoryBar,
  quarter: TrendLine,
  line: TrendLine,
  donut: CompositionDonut,
  ranking: RankingBar,
}

export default function Charts({ rows, analysis }) {
  const charts = analysis.charts
  if (!charts || charts.length === 0) {
    return (
      <section className="charts-grid">
        <div className="chart-card">
          <div className="chart-empty">
            차트로 만들 수 있는 숫자 컬럼이나 분류 컬럼을 찾지 못했습니다. 아래 표에서 원본
            데이터를 확인해 주세요.
          </div>
        </div>
      </section>
    )
  }

  // 각 차트는 선택된 기준/값을 state로 들고 있다. 파일이 바뀌면 그 state가 이전 파일의
  // 컬럼명을 가리켜 빈 차트가 되므로, 시그니처를 key에 넣어 새 데이터마다 다시 마운트한다.
  return (
    <section className="charts-grid">
      {charts.map((spec) => {
        const Renderer = RENDERERS[spec.type]
        return Renderer ? (
          <Renderer
            key={`${spec.id}::${analysis.signature}`}
            rows={rows}
            spec={spec}
            analysis={analysis}
          />
        ) : null
      })}
    </section>
  )
}
