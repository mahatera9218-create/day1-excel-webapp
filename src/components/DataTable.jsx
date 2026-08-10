import { useEffect, useMemo, useState } from 'react'
import { formatCell } from '../utils/format'

export default function DataTable({ headers, rows, analysis, excludedTotalRows = 0 }) {
  const [search, setSearch] = useState('')
  const [filterValue, setFilterValue] = useState('전체')
  const filterColumn = analysis.filterColumn

  // 파일이 바뀌면 이전 파일 기준의 필터가 남지 않도록 초기화한다.
  useEffect(() => {
    setSearch('')
    setFilterValue('전체')
  }, [headers, filterColumn])

  const filterOptions = useMemo(() => {
    if (!filterColumn) return []
    const set = new Set(rows.map((r) => String(r[filterColumn] ?? '')).filter(Boolean))
    return ['전체', ...Array.from(set).sort((a, b) => a.localeCompare(b, 'ko'))]
  }, [rows, filterColumn])

  const filteredRows = useMemo(() => {
    let result = rows
    if (filterColumn && filterValue !== '전체') {
      result = result.filter((r) => String(r[filterColumn] ?? '') === filterValue)
    }
    if (search.trim()) {
      const q = search.trim().toLowerCase()
      result = result.filter((r) => headers.some((h) => String(r[h] ?? '').toLowerCase().includes(q)))
    }
    return result
  }, [rows, headers, search, filterColumn, filterValue])

  const isNumeric = (name) => {
    const kind = analysis.byName[name]?.kind
    return kind === 'number' || kind === 'percent'
  }

  return (
    <section className="table-section">
      <div className="table-toolbar">
        <div className="table-title">
          원본 데이터 ({filteredRows.length.toLocaleString('ko-KR')}행)
          {excludedTotalRows > 0 && (
            <span className="table-note">합계 행 {excludedTotalRows}개 제외됨</span>
          )}
        </div>
        <div className="table-controls">
          {filterColumn && filterOptions.length > 1 && (
            <select
              className="filter-select"
              value={filterValue}
              onChange={(e) => setFilterValue(e.target.value)}
            >
              {filterOptions.map((opt) => (
                <option key={opt} value={opt}>
                  {filterColumn}: {opt}
                </option>
              ))}
            </select>
          )}
          <input
            className="search-input"
            type="text"
            placeholder="검색어를 입력하세요..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
      </div>
      <div className="table-scroll">
        <table>
          <thead>
            <tr>
              {headers.map((h) => (
                <th key={h} className={isNumeric(h) ? 'num' : undefined}>
                  {h}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {filteredRows.length === 0 ? (
              <tr>
                <td className="table-empty" colSpan={headers.length}>
                  표시할 데이터가 없습니다.
                </td>
              </tr>
            ) : (
              filteredRows.map((row, i) => (
                <tr key={i}>
                  {headers.map((h) => (
                    <td key={h} className={isNumeric(h) ? 'num' : undefined}>
                      {formatCell(row[h], analysis.byName[h])}
                    </td>
                  ))}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </section>
  )
}
