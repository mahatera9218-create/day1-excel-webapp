import { useMemo, useState } from 'react'
import UploadArea from './components/UploadArea'
import KpiCards from './components/KpiCards'
import Charts from './components/Charts'
import DataTable from './components/DataTable'
import { parseWorkbookFile } from './utils/parseExcel'
import { analyzeDataset } from './utils/analyze'

const EMPTY = { sheetName: '', headers: [], rows: [], units: {}, excludedTotalRows: 0 }

export default function App() {
  const [fileName, setFileName] = useState('')
  const [data, setData] = useState(EMPTY)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  // 업로드된 시트를 분석해 지표·차트 구성을 만든다. 파일이 바뀌면 구성도 함께 바뀐다.
  const analysis = useMemo(
    () => analyzeDataset(data.headers, data.rows, data.units),
    [data]
  )

  const handleFile = async (file) => {
    if (!file.name.toLowerCase().endsWith('.xlsx')) {
      setError('.xlsx 파일만 업로드할 수 있습니다.')
      return
    }
    setError('')
    setLoading(true)
    try {
      const result = await parseWorkbookFile(file)
      if (result.rows.length === 0) {
        setError('시트에서 데이터를 찾을 수 없습니다.')
      } else {
        setFileName(file.name)
        setData(result)
      }
    } catch (err) {
      console.error(err)
      setError('파일을 읽는 중 오류가 발생했습니다. 형식을 확인해주세요.')
    } finally {
      setLoading(false)
    }
  }

  const hasData = data.rows.length > 0

  return (
    <div className="app">
      <header className="app-header">
        <div className="app-header-inner">
          <h1>
            <span className="app-logo">🌐</span> 해외법인 실적 대시보드
          </h1>
          {fileName && <span className="app-file-badge">{fileName}</span>}
        </div>
      </header>

      <main className="app-main">
        <UploadArea
          onFile={handleFile}
          fileName={loading ? '' : fileName}
          error={error}
          summary={hasData && !loading ? buildSummary(data, analysis) : null}
        />

        {loading && <div className="loading-banner">엑셀 파일을 분석하는 중입니다...</div>}

        {hasData && (
          <>
            <KpiCards rows={data.rows} kpis={analysis.kpis} />
            <Charts rows={data.rows} analysis={analysis} />
            <DataTable
              headers={data.headers}
              rows={data.rows}
              analysis={analysis}
              excludedTotalRows={data.excludedTotalRows}
            />
          </>
        )}

        {!hasData && !loading && (
          <div className="empty-hint">
            엑셀 파일을 업로드하면 컬럼을 분석해 핵심 지표, 차트, 데이터 표를 자동으로 구성합니다.
          </div>
        )}
      </main>
    </div>
  )
}

// 어떤 기준으로 화면이 구성됐는지 사용자가 알 수 있게 요약한다.
function buildSummary(data, analysis) {
  const chips = [
    `시트 ${data.sheetName}`,
    `${data.rows.length.toLocaleString('ko-KR')}행 · ${data.headers.length}컬럼`,
  ]
  if (analysis.numericCols.length + analysis.percentCols.length > 0) {
    chips.push(`숫자 ${analysis.numericCols.length + analysis.percentCols.length}개`)
  }
  if (analysis.groupDims.length > 0) {
    chips.push(`분류 기준 ${analysis.groupDims.map((d) => d.name).slice(0, 3).join(', ')}`)
  }
  if (analysis.periodCol) chips.push(`기간 ${analysis.periodCol.name}`)
  if (analysis.quarterGroups.length > 0) chips.push('분기 컬럼 인식')
  return chips
}
