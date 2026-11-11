"""업로드: 롱폼(비공개) + 쇼츠(각자 제목·설명)를 유튜브에 올린다. mock 모드면 안내만.

인증(token.json)이 없거나 업로드가 실패해도 렌더는 죽지 않는다 — 경고만 찍고 넘어가서,
영상·썸네일·쇼츠는 .dev 업로드 키트에서 그대로 받을 수 있게 둔다.
"""

from pathlib import Path


def run_stage(run_dir: Path, plan: dict, cfg: dict, shorts: bool = True) -> None:
    final = run_dir / "final.mp4"
    if cfg["engines"]["mode"] == "mock":
        print(f"      [mock] 업로드 생략. 결과물: {final}")
        return
    ch = cfg["_dir"]
    if not (ch / "token.json").exists() and not (ch / cfg["youtube"]["client_secret_file"]).exists():
        print(f"      [안내] 유튜브 인증이 없어 업로드는 건너뜁니다(.dev 키트에서 받으세요). {final}")
        return
    try:
        from ..engines.youtube import upload
        vid = upload(final, plan, cfg, thumbnail=run_dir / "thumbnail.jpg")
        (run_dir / "youtube_id.txt").write_text(vid, encoding="utf-8")
        long_url = f"https://youtu.be/{vid}"
        print(f"      롱폼 → {long_url}  (비공개/임시저장)")
        if shorts:
            specs = plan.get("shorts") or []
            for i, sp_file in enumerate(sorted((run_dir / "shorts").glob("short_*.mp4"))):
                meta = specs[i] if i < len(specs) else {}
                stitle = (meta.get("title") or f"{plan['title']} #Shorts")[:100]
                sdesc = (meta.get("description") or plan.get("description", "")).strip()
                # 쇼츠 → 롱폼 유입: 설명 맨 위에 '풀스토리' 링크를 박는다
                sdesc = f"▶ FULL STORY: {long_url}\n\n{sdesc}"
                short_plan = {**plan, "title": stitle, "description": sdesc}
                sv = upload(sp_file, short_plan, cfg)
                print(f"      쇼츠 {sp_file.name} → https://youtu.be/{sv}  (비공개)")
    except Exception as e:  # noqa: BLE001 — 업로드 실패가 렌더 전체를 죽이지 않게
        print(f"      [경고] 유튜브 업로드 실패(건너뜀): {e}")
        print(f"      결과물은 .dev 업로드 키트에서 직접 받아 올리세요: {final}")
