import * as XLSX from 'xlsx'
import { extractUnit } from './format'

// 제목/배너 행을 건너뛰고 실제 컬럼 헤더 행을 찾는다.
// 헤더 행은 대부분의 셀이 채워진 첫 번째 행이라는 휴리스틱을 사용한다.
function findHeaderRowIndex(rows) {
  for (let i = 0; i < Math.min(rows.length, 15); i++) {
    const row = rows[i]
    if (!row || row.length === 0) continue
    const filled = row.filter((c) => c !== '' && c !== null && c !== undefined).length
    if (filled >= Math.max(3, row.length * 0.6)) {
      return i
    }
  }
  return 0
}

// 컬럼별 단위를 만든다.
// 단위는 컬럼 헤더 자체("총액(USD)")에 있을 수도 있고, 바로 윗줄의 그룹 헤더
// ("매출 (백만원)")에 있을 수도 있다. 그룹 헤더는 병합 셀이라 첫 칸에만 값이 있으므로
// 오른쪽으로 이어서 채운 뒤 각 컬럼에 물려 준다.
function buildColumnUnits(raw, headerIdx, headerRow) {
  const groupRow = headerIdx > 0 ? raw[headerIdx - 1] || [] : []
  const carriedLabels = []
  let carried = ''
  for (let i = 0; i < headerRow.length; i++) {
    const cell = groupRow[i]
    const text = cell === null || cell === undefined ? '' : String(cell).trim()
    if (text) carried = text
    carriedLabels[i] = carried
  }

  const units = {}
  headerRow.forEach((name, i) => {
    units[name] = extractUnit(name) || extractUnit(carriedLabels[i]) || ''
  })
  return units
}

// 엑셀 하단의 "ANNUAL TOTAL", "합계" 같은 요약 행은 데이터가 아니므로 집계에서 제외한다.
// 합계 행은 라벨 셀에 키워드가 있고 나머지 셀이 상당수 비어 있다는 점으로 판별해,
// "TOTAL ENERGY CORP" 같은 정상 데이터의 오탐을 막는다.
const TOTAL_KEYWORD = /(합\s*계|총\s*계|소\s*계|누\s*계|total|subtotal|sum)/i

function isTotalRow(row) {
  const cells = row.map((c) => (c === null || c === undefined ? '' : String(c).trim()))
  const labelHasKeyword = cells.slice(0, 3).some((c) => c && TOTAL_KEYWORD.test(c))
  if (!labelHasKeyword) return false
  const emptyRatio = cells.filter((c) => c === '').length / Math.max(cells.length, 1)
  return emptyRatio >= 0.2
}

export function parseWorkbookFile(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = (e) => {
      try {
        const data = new Uint8Array(e.target.result)
        const workbook = XLSX.read(data, { type: 'array' })
        const firstSheetName = workbook.SheetNames[0]
        const sheet = workbook.Sheets[firstSheetName]
        const raw = XLSX.utils.sheet_to_json(sheet, { header: 1, defval: '' })

        const headerIdx = findHeaderRowIndex(raw)
        const headerRow = (raw[headerIdx] || []).map((h, i) =>
          h === '' || h === null || h === undefined ? `컬럼${i + 1}` : String(h).trim()
        )

        const nonEmptyRows = raw
          .slice(headerIdx + 1)
          .filter((row) => row.some((c) => c !== '' && c !== null && c !== undefined))

        const dataRows = nonEmptyRows.filter((row) => !isTotalRow(row))
        const totalRowCount = nonEmptyRows.length - dataRows.length

        const records = dataRows.map((row) => {
          const obj = {}
          headerRow.forEach((h, i) => {
            obj[h] = row[i] === undefined ? '' : row[i]
          })
          return obj
        })

        resolve({
          sheetName: firstSheetName,
          headers: headerRow,
          rows: records,
          units: buildColumnUnits(raw, headerIdx, headerRow),
          excludedTotalRows: totalRowCount,
        })
      } catch (err) {
        reject(err)
      }
    }
    reader.onerror = reject
    reader.readAsArrayBuffer(file)
  })
}

