import { aggregateKpi } from '../utils/analyze'
import { formatNumber, formatCompact } from '../utils/format'

const ACCENTS = ['accent-teal', 'accent-blue', 'accent-purple', 'accent-cyan', 'accent-amber']

// 자릿수가 길면 카드가 줄바꿈되므로, 큰 값은 축약 표기를 함께 보여 준다.
function renderValue(value, card) {
  if (!Number.isFinite(value)) return { main: '-', sub: '', unit: '' }

  if (card.agg === 'count' || card.agg === 'unique') {
    return { main: formatNumber(value, 0), sub: '', unit: card.suffix || '' }
  }

  const col = card.column || {}
  const unit = col.kind === 'percent' ? '%' : col.unit || ''
  // 합계처럼 큰 값은 소수점을 떼야 읽힌다. 비율은 소수 자릿수를 유지한다.
  const decimals =
    col.kind !== 'percent' && Math.abs(value) >= 1e4 ? 0 : col.decimals ?? 0
  const main = formatNumber(value, decimals)
  const sub = Math.abs(value) >= 1e6 ? formatCompact(value) : ''
  return { main, sub, unit }
}

export default function KpiCards({ rows, kpis }) {
  if (!kpis || kpis.length === 0) return null

  return (
    <section className="kpi-grid">
      {kpis.map((card, i) => {
        const value = aggregateKpi(rows, card)
        const { main, sub, unit } = renderValue(value, card)
        return (
          <div className={`kpi-card ${ACCENTS[i % ACCENTS.length]}`} key={card.key}>
            <div className="kpi-icon">{card.icon}</div>
            <div className="kpi-body">
              <div className="kpi-label" title={card.label}>
                {card.label}
              </div>
              <div className="kpi-value">
                {main}
                {unit && <span className="kpi-suffix">{unit === '%' ? '%' : unit}</span>}
              </div>
              {sub && <div className="kpi-sub">≈ {sub}</div>}
            </div>
          </div>
        )
      })}
    </section>
  )
}
