"""업로드: 롱폼(비공개) + 쇼츠를 유튜브에 올린다. mock 모드면 안내만 출력."""

from pathlib import Path


def run_stage(run_dir: Path, plan: dict, cfg: dict, shorts: bool = True) -> None:
    final = run_dir / "final.mp4"
    if cfg["engines"]["mode"] == "mock":
        print(f"      [mock] 업로드 생략. 결과물: {final}")
        return
    # 유튜브 OAuth(토큰/클라이언트 시크릿)가 아직 없으면 업로드만 건너뛴다.
    # (영상·썸네일·쇼츠는 그대로 만들어져 Actions 결과물에서 내려받을 수 있다.)
    ch = cfg["_dir"]
    if not (ch / "token.json").exists() and not (ch / cfg["youtube"]["client_secret_file"]).exists():
        print(f"      [안내] 유튜브 인증이 없어 업로드는 건너뜁니다. 결과물: {final}")
        return
    from ..engines.youtube import upload
    vid = upload(final, plan, cfg)
    (run_dir / "youtube_id.txt").write_text(vid, encoding="utf-8")
    print(f"      롱폼 → https://youtu.be/{vid}  (비공개/임시저장)")
    if shorts:
        for sp in sorted((run_dir / "shorts").glob("short_*.mp4")):
            short_plan = {**plan, "title": f"{plan['title']} #Shorts",
                          "description": plan["description"] + "\n\n#Shorts"}
            sv = upload(sp, short_plan, cfg)
            print(f"      쇼츠 {sp.name} → https://youtu.be/{sv}")
