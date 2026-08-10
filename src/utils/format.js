// 화면 전체의 숫자 표기 규칙을 이 파일 하나로 통일한다.
//
// 규칙
//  - 모든 숫자는 천 단위 컴마(ko-KR)를 적용한다.
//  - 소수 자릿수는 컬럼 단위로 고정한다. 정수만 있으면 0자리, 소수가 섞이면 2자리,
//    비율(%) 컬럼은 1자리. 같은 컬럼 안에서 자릿수가 들쭉날쭉하지 않게 한다.
//  - 표 셀에는 단위를 붙이지 않는다(헤더에 이미 있음). 카드·툴팁에만 단위를 붙인다.
//  - 차트 축처럼 공간이 좁은 곳은 만/억/조 축약 표기를 쓴다.

const NUM_CLEAN_RE = /[,\s￦$€¥]/g

// 헤더 끝의 괄호에서 단위를 뽑는다. "총액(USD)" → "USD", "매출 (백만원)" → "백만원"
const UNIT_RE = /[(（]([^()（）]{1,12})[)）]\s*$/

export function extractUnit(header) {
  const m = String(header ?? '').match(UNIT_RE)
  return m ? m[1].trim() : ''
}

// 숫자로 해석되면 number, 아니면 null. "-", "N/A" 같은 자리표시자를 0으로 만들지 않는다.
export function parseNumOrNull(v) {
  if (typeof v === 'number') return Number.isFinite(v) ? v : null
  if (typeof v !== 'string') return null
  const s = v.replace(NUM_CLEAN_RE, '').replace(/%$/, '')
  if (s === '' || !/^[+-]?\d*\.?\d+(e[+-]?\d+)?$/i.test(s)) return null
  const n = Number(s)
  return Number.isFinite(n) ? n : null
}

export function toNumber(v) {
  return parseNumOrNull(v) ?? 0
}

export function formatNumber(n, decimals = 0) {
  if (!Number.isFinite(n)) return '-'
  return new Intl.NumberFormat('ko-KR', {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  }).format(n)
}

// 축·라벨용 축약 표기. 자릿수가 길어 축이 뭉개지는 것을 막는다.
export function formatCompact(n) {
  if (!Number.isFinite(n)) return '-'
  if (n === 0) return '0'
  const abs = Math.abs(n)
  if (abs >= 1e12) return `${scaled(n, 1e12)}조`
  if (abs >= 1e8) return `${scaled(n, 1e8)}억`
  if (abs >= 1e4) return `${scaled(n, 1e4)}만`
  if (abs >= 1) return formatNumber(n, Number.isInteger(n) ? 0 : 1)
  return formatNumber(n, 2)
}

function scaled(n, divisor) {
  const v = n / divisor
  return formatNumber(v, Number.isInteger(v) ? 0 : 1)
}

// 하나의 축 안에서 단위가 섞이지 않도록, 최댓값을 기준으로 눈금 표기를 한 번만 정한다.
// (예: 7,500 / 1.5만 / 2.3만 처럼 뒤섞이는 것을 막는다)
export function createAxisFormatter(values) {
  const max = values.reduce((m, v) => Math.max(m, Math.abs(Number(v) || 0)), 0)
  let divisor = 1
  let suffix = ''
  if (max >= 1e12) {
    divisor = 1e12
    suffix = '조'
  } else if (max >= 1e8) {
    divisor = 1e8
    suffix = '억'
  } else if (max >= 1e6) {
    divisor = 1e4
    suffix = '만'
  }

  return (n) => {
    if (!Number.isFinite(n)) return ''
    if (n === 0) return '0'
    const v = n / divisor
    const decimals = divisor === 1 ? (Number.isInteger(v) ? 0 : 1) : Number.isInteger(v) ? 0 : 1
    return `${formatNumber(v, decimals)}${suffix}`
  }
}

// 컬럼 메타(kind/decimals)에 맞춰 표 셀 값을 만든다.
export function formatCell(raw, column) {
  if (raw === '' || raw === null || raw === undefined) return ''
  if (column && (column.kind === 'number' || column.kind === 'percent')) {
    const n = parseNumOrNull(raw)
    if (n === null) return String(raw) // "-" 같은 값은 원본 그대로 둔다
    return formatNumber(n, column.decimals)
  }
  return String(raw)
}

// 카드·툴팁용. 값 뒤에 단위를 붙인다.
export function formatWithUnit(n, column, { compact = false } = {}) {
  if (!Number.isFinite(n)) return '-'
  const decimals = column?.decimals ?? 0
  const body = compact ? formatCompact(n) : formatNumber(n, decimals)
  const unit = column?.kind === 'percent' ? '%' : column?.unit || ''
  if (!unit) return body
  return unit === '%' ? `${body}%` : `${body} ${unit}`
}

export function formatPercent(n, decimals = 1) {
  if (!Number.isFinite(n)) return '-'
  return `${formatNumber(n, decimals)}%`
}
