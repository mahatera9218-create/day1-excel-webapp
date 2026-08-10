import { parseNumOrNull, extractUnit } from './format'

// 업로드된 시트의 컬럼을 분류해서, 어떤 지표와 차트를 만들지 스스로 결정한다.
// 특정 양식(해외법인 등)에 맞춘 고정 로직 대신 컬럼의 성격을 보고 구성한다.

const ID_RE = /코드|번호|no\.?$|^id$|id$/i
const PERCENT_RE = /\(\s*%\s*\)|률$|율$|비율|증감|대비/
const DATE_VALUE_RE = /^\d{4}[-/.]\d{1,2}([-/.]\d{1,2})?$/
const PERIOD_NAME_RE = /^(월|년월|분기|일자|날짜|기간)|일$|월$/

// 합계 성격의 값으로 볼 수 있는 컬럼일수록 점수가 높다.
const MEASURE_RULES = [
  { re: /매출|총액|금액|revenue|amount|sales/, score: 100 },
  { re: /영업이익|순이익|이익(?!률|율)|profit/, score: 92 },
  { re: /발전량|생산량|거래량|물동량|처리량|저장량|송출량|반출입|판매량/, score: 84 },
  { re: /수량|중량|톤|용량/, score: 62 },
  { re: /온실가스|배출|소비/, score: 58 },
  { re: /인원|임직원|직원|건수/, score: 40 },
]

// 합산이 의미 없는(평균이 맞는) 컬럼
const AVG_RE = /단가|평균|률$|율$|비율|등급|지수|효율|원단위|단위연료|대비/

const DIM_RULES = [
  { re: /^지역$|^권역$/, score: 100 },
  { re: /^구역$|^부문$|사업부문|^사업유형$|^유형$/, score: 92 },
  { re: /^국가$|^지사$|^지점$|담당지점/, score: 80 },
  { re: /운영지표|^구분$|^분류$|^항목$/, score: 74 },
  { re: /등급|상태|조건|^단위$/, score: 50 },
]

const ENTITY_RE = /법인명|명$|고객사|거래처|사$/

// 비고·메모류는 분류 축으로도 개체 축으로도 의미가 없으므로 후보에서 뺀다.
const NOTE_RE = /비고|메모|특이사항|참고|설명|note|remark|comment/i

function uniqueValues(rows, name) {
  const set = new Set()
  for (const r of rows) {
    const v = r[name]
    if (v !== '' && v !== null && v !== undefined) set.add(String(v))
  }
  return set
}

function scoreBy(rules, name) {
  for (const rule of rules) {
    if (rule.re.test(name)) return rule.score
  }
  return 0
}

/** 각 컬럼의 성격(숫자/비율/기간/텍스트)과 표시 규칙을 판정한다. */
export function analyzeColumns(headers, rows, units = {}) {
  return headers.map((name) => {
    const values = rows.map((r) => r[name])
    const nonEmpty = values.filter((v) => v !== '' && v !== null && v !== undefined)
    const nums = nonEmpty.map(parseNumOrNull).filter((n) => n !== null)
    const numericRatio = nonEmpty.length ? nums.length / nonEmpty.length : 0
    const uniq = uniqueValues(rows, name)

    const looksLikeDate =
      nonEmpty.length > 0 &&
      nonEmpty.filter((v) => DATE_VALUE_RE.test(String(v).trim())).length / nonEmpty.length > 0.8
    const isId = ID_RE.test(name) && uniq.size > rows.length * 0.5
    const isPercent = PERCENT_RE.test(name)

    let kind
    if (looksLikeDate || (PERIOD_NAME_RE.test(name) && numericRatio < 0.8)) kind = 'period'
    else if (numericRatio >= 0.8 && !isId && nums.length > 0) kind = isPercent ? 'percent' : 'number'
    else kind = 'text'

    const allInt = nums.every((n) => Number.isInteger(n))
    const decimals = kind === 'percent' ? (allInt ? 0 : 1) : allInt ? 0 : 2

    return {
      name,
      kind,
      unit: units[name] || extractUnit(name),
      decimals,
      uniqueCount: uniq.size,
      isId,
      sum: nums.reduce((s, n) => s + n, 0),
      count: nums.length,
    }
  })
}

/** "Q1매출, Q2매출, ..." 처럼 분기가 컬럼으로 펼쳐진 묶음을 찾는다. */
function findQuarterGroups(columns) {
  const buckets = new Map()
  for (const col of columns) {
    if (col.kind !== 'number') continue
    const m = col.name.match(/^Q([1-4])\s*(.*)$/) || col.name.match(/^([1-4])분기\s*(.*)$/)
    if (!m) continue
    const suffix = (m[2] || '값').trim()
    if (!buckets.has(suffix)) buckets.set(suffix, [])
    buckets.get(suffix)[Number(m[1]) - 1] = col.name
  }
  return [...buckets.entries()]
    .filter(([, cols]) => cols.filter(Boolean).length === 4)
    .map(([label, cols]) => ({ label, columns: cols }))
}

function measureScore(col) {
  let score = scoreBy(MEASURE_RULES, col.name)
  if (score === 0) score = 20 // 키워드가 없어도 숫자 컬럼이면 후보로 둔다
  if (/^(연|년)/.test(col.name)) score += 12 // 연매출 > Q1매출
  if (/합계|^계$|총/.test(col.name)) score += 8
  if (/^Q[1-4]|분기/.test(col.name)) score -= 30 // 분기 컬럼은 추이 차트에서 다룬다
  if (/^\d/.test(col.name)) score -= 25 // "1탱크" 같은 계열 컬럼
  return score
}

function labelForSum(col) {
  let base = col.name.replace(/\s*[(（].*$/, '').trim()
  // "연매출 → 매출"처럼 기간 접두사만 떼어 낸다.
  // "연료소비"의 "연"까지 잘려 "료소비"가 되지 않도록 뒤에 오는 말을 확인한다.
  base = base.replace(/^연간(?=.)/, '')
  base = base.replace(/^연(?=(매출|영업이익|순이익|이익|판매|생산|매입|수익))/, '')
  if (!base || /^(합계|계|총계)$/.test(base)) return '전체 합계'
  return `${base} 합계`
}

function labelForAvg(col) {
  const base = col.name.replace(/\s*[(（].*$/, '').trim()
  return `평균 ${base}`
}

const KPI_ICONS = ['💰', '📈', '📊', '🏢', '⚡', '📦']

/** 시트 전체를 분석해서 지표 카드와 차트 구성을 만들어 낸다. */
export function analyzeDataset(headers, rows, units = {}) {
  const columns = analyzeColumns(headers, rows, units)
  const byName = Object.fromEntries(columns.map((c) => [c.name, c]))

  const numericCols = columns.filter((c) => c.kind === 'number')
  const percentCols = columns.filter((c) => c.kind === 'percent')
  const periodCol = columns.find((c) => c.kind === 'period') || null
  const quarterGroups = findQuarterGroups(columns)

  // 그룹 축: 값의 종류가 적어 묶어 보기 좋은 텍스트 컬럼
  const groupDims = columns
    .filter(
      (c) =>
        c.kind === 'text' &&
        !c.isId &&
        !NOTE_RE.test(c.name) &&
        c.uniqueCount >= 2 &&
        c.uniqueCount <= 15 &&
        c.uniqueCount < rows.length
    )
    .sort((a, b) => scoreBy(DIM_RULES, b.name) - scoreBy(DIM_RULES, a.name) || a.uniqueCount - b.uniqueCount)

  // 개체 축: 법인명·발전소명처럼 종류가 많은 이름 컬럼 (상위 N 비교용)
  const entityDims = columns
    .filter(
      (c) =>
        c.kind === 'text' &&
        !c.isId &&
        !NOTE_RE.test(c.name) &&
        c.uniqueCount > 5 &&
        c.uniqueCount <= rows.length
    )
    .sort(
      (a, b) =>
        (ENTITY_RE.test(b.name) ? 1 : 0) - (ENTITY_RE.test(a.name) ? 1 : 0) ||
        b.uniqueCount - a.uniqueCount
    )
  const entityDim = entityDims[0] || null

  // 지표 후보
  const sumMeasures = numericCols
    .filter((c) => !AVG_RE.test(c.name))
    .map((c) => ({ column: c, agg: 'sum', score: measureScore(c) }))
    .sort((a, b) => b.score - a.score || b.column.sum - a.column.sum)

  const avgMeasures = [...percentCols, ...numericCols.filter((c) => AVG_RE.test(c.name))]
    .map((c) => ({ column: c, agg: 'avg', score: scoreBy(MEASURE_RULES, c.name) + 10 }))
    .sort((a, b) => b.score - a.score)

  // ── 지표 카드 구성 ─────────────────────────────────────────
  const cards = []
  const revenue = sumMeasures.find((m) => /매출|총액|금액|revenue|sales/.test(m.column.name))
  const profit = sumMeasures.find((m) => /영업이익|순이익|profit/.test(m.column.name))

  // 첫 지표는 무조건 세우고, 두 번째는 이름에서 의미가 확인되는 컬럼일 때만 세운다.
  // ("1탱크, 2탱크"처럼 합계의 구성 요소일 뿐인 컬럼이 대표 지표로 올라오는 것을 막는다.)
  if (sumMeasures[0]) {
    const m = sumMeasures[0]
    cards.push({ key: m.column.name, label: labelForSum(m.column), column: m.column, agg: 'sum' })
  }
  if (sumMeasures[1] && sumMeasures[1].score >= 40) {
    const m = sumMeasures[1]
    cards.push({ key: m.column.name, label: labelForSum(m.column), column: m.column, agg: 'sum' })
  }

  // 매출과 이익이 함께 있으면 이익률은 파생 지표로 계산한다(단순 평균이 아닌 가중 평균).
  if (revenue && profit) {
    cards.push({
      key: '__margin',
      label: '평균 영업이익률',
      agg: 'ratio',
      numerator: profit.column.name,
      denominator: revenue.column.name,
      column: { kind: 'percent', decimals: 1, unit: '%' },
    })
  } else if (avgMeasures[0]) {
    cards.push({
      key: avgMeasures[0].column.name,
      label: labelForAvg(avgMeasures[0].column),
      column: avgMeasures[0].column,
      agg: 'avg',
    })
  } else if (sumMeasures[2]) {
    cards.push({
      key: sumMeasures[2].column.name,
      label: labelForSum(sumMeasures[2].column),
      column: sumMeasures[2].column,
      agg: 'sum',
    })
  }

  // 마지막 카드는 건수. 한 행이 곧 한 개체면 "법인 수"처럼 이름을 바꿔 준다.
  const entityBase = entityDim ? entityDim.name.replace(/명$/, '') : null
  if (entityDim && entityDim.uniqueCount === rows.length) {
    cards.push({ key: '__count', label: `${entityBase} 수`, agg: 'count', suffix: '개' })
  } else if (entityDim) {
    cards.push({
      key: '__uniq',
      label: `${entityBase} 수`,
      agg: 'unique',
      dimension: entityDim.name,
      suffix: '개',
    })
  } else {
    cards.push({ key: '__count', label: '데이터 건수', agg: 'count', suffix: '건' })
  }

  const kpis = cards.slice(0, 4).map((c, i) => ({ ...c, icon: KPI_ICONS[i] }))

  // ── 차트 구성 ──────────────────────────────────────────────
  const primary = sumMeasures[0]?.column || numericCols[0] || null
  const secondary = profit?.column || sumMeasures[1]?.column || primary
  const charts = []

  if (groupDims[0] && primary) {
    charts.push({
      id: 'category',
      type: 'bar',
      title: '항목별 비교',
      dimension: groupDims[0].name,
      measure: primary.name,
    })
  }

  if (quarterGroups.length > 0) {
    charts.push({
      id: 'trend',
      type: 'quarter',
      title: '분기별 추이',
      groups: quarterGroups,
      group: quarterGroups[0].label,
    })
  } else if (periodCol && primary) {
    charts.push({
      id: 'trend',
      type: 'line',
      title: '기간별 추이',
      period: periodCol.name,
      measure: primary.name,
    })
  }

  if (groupDims[1] && primary) {
    charts.push({
      id: 'composition',
      type: 'donut',
      title: '구성비',
      dimension: groupDims[1].name,
      measure: primary.name,
    })
  }

  if (entityDim && secondary && entityDim.uniqueCount > 3) {
    charts.push({
      id: 'ranking',
      type: 'ranking',
      title: '상위 항목 비교',
      dimension: entityDim.name,
      measure: secondary.name,
      wide: true,
    })
  }

  return {
    // 데이터셋이 바뀐 것을 화면이 알아챌 수 있게 하는 식별자
    signature: `${headers.join('|')}#${rows.length}`,
    columns,
    byName,
    numericCols,
    percentCols,
    groupDims,
    entityDims,
    entityDim,
    periodCol,
    quarterGroups,
    measureNames: [...new Set([...sumMeasures, ...avgMeasures].map((m) => m.column.name))],
    kpis,
    charts,
    filterColumn: groupDims[0]?.name || null,
  }
}

// ── 집계 유틸 ────────────────────────────────────────────────

export function aggregateKpi(rows, card) {
  if (card.agg === 'count') return rows.length
  if (card.agg === 'unique') return uniqueValues(rows, card.dimension).size
  if (card.agg === 'ratio') {
    const num = sumOf(rows, card.numerator)
    const den = sumOf(rows, card.denominator)
    return den === 0 ? NaN : (num / den) * 100
  }
  if (card.agg === 'avg') return avgOf(rows, card.key)
  return sumOf(rows, card.key)
}

function sumOf(rows, name) {
  let s = 0
  for (const r of rows) {
    const n = parseNumOrNull(r[name])
    if (n !== null) s += n
  }
  return s
}

function avgOf(rows, name) {
  let s = 0
  let c = 0
  for (const r of rows) {
    const n = parseNumOrNull(r[name])
    if (n !== null) {
      s += n
      c += 1
    }
  }
  return c === 0 ? NaN : s / c
}

/** 차원별로 묶어 합계(또는 평균)를 낸다. */
export function aggregateBy(rows, dimension, measureName, agg = 'sum') {
  const map = new Map()
  for (const r of rows) {
    const key = String(r[dimension] ?? '').trim() || '(미지정)'
    const n = parseNumOrNull(r[measureName])
    if (n === null) continue
    const cur = map.get(key) || { sum: 0, count: 0 }
    cur.sum += n
    cur.count += 1
    map.set(key, cur)
  }
  return [...map.entries()].map(([name, v]) => ({
    name,
    value: agg === 'avg' ? v.sum / v.count : v.sum,
  }))
}

/** 기간 컬럼을 시간순으로 묶는다. 값이 너무 잘게 나뉘면 월 단위로 합친다. */
export function aggregateByPeriod(rows, periodName, measureName) {
  const raw = [...new Set(rows.map((r) => String(r[periodName] ?? '').trim()).filter(Boolean))]
  const bucketToMonth = raw.length > 24 && raw.every((v) => /^\d{4}[-/.]\d{1,2}[-/.]\d{1,2}$/.test(v))
  const map = new Map()
  for (const r of rows) {
    let key = String(r[periodName] ?? '').trim()
    if (!key) continue
    if (bucketToMonth) key = key.slice(0, 7)
    const n = parseNumOrNull(r[measureName])
    if (n === null) continue
    map.set(key, (map.get(key) || 0) + n)
  }
  return [...map.entries()]
    .sort((a, b) => String(a[0]).localeCompare(String(b[0]), 'ko'))
    .map(([name, value]) => ({ name, value }))
}

export function aggregateQuarters(rows, group) {
  return group.columns.map((colName, i) => ({
    name: `Q${i + 1}`,
    value: sumOf(rows, colName),
  }))
}
