export default function UploadArea({ onFile, fileName, error, summary }) {
  const handleChange = (e) => {
    const file = e.target.files?.[0]
    if (file) onFile(file)
  }

  const handleDrop = (e) => {
    e.preventDefault()
    const file = e.dataTransfer.files?.[0]
    if (file) onFile(file)
  }

  return (
    <section className="upload-area" onDragOver={(e) => e.preventDefault()} onDrop={handleDrop}>
      <div className="upload-icon">📊</div>
      <div className="upload-text">
        <label className="upload-btn">
          파일 선택
          <input type="file" accept=".xlsx" onChange={handleChange} hidden />
        </label>
        <p className="upload-hint">
          .xlsx 파일을 업로드하면 첫 번째 시트의 컬럼을 분석해 지표와 차트를 자동으로 구성합니다.
          (드래그 앤 드롭도 가능합니다)
        </p>
        {fileName && <p className="upload-filename">✅ {fileName}</p>}
        {summary && (
          <div className="upload-summary">
            {summary.map((chip) => (
              <span className="summary-chip" key={chip}>
                {chip}
              </span>
            ))}
          </div>
        )}
        {error && <p className="upload-error">⚠ {error}</p>}
      </div>
    </section>
  )
}
