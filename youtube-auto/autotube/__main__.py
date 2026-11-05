"""AI 롱폼 유튜브 자동 제작 — 명령 진입점.

  autotube new <채널> --topic "소재"    새 편 기획 → plan.json + script.md (검토용)
  autotube approve <폴더>               검토 완료 표시
  autotube make <폴더> [--yes]          목소리·그림·합성·썸네일·쇼츠 (끊기면 다시 실행 시 이어서)
  autotube upload <폴더>                유튜브 비공개 업로드
  autotube run <채널> --mock            키 없이 기획→완성까지 한 번에 (시험용)
  autotube status <폴더>                진행 상황
  autotube list                         채널 목록
"""

import argparse
import json
import re
from datetime import datetime
from pathlib import Path

from . import pipeline
from .config import CHANNELS, OUTPUT, load_channel, load_env
from .stages import plan as plan_stage


def _slug(text: str) -> str:
    return re.sub(r"[^\w가-힣]+", "-", text).strip("-")[:40]


def _next_topic(cfg: dict) -> str:
    used = {json.loads(p.read_text(encoding="utf-8")).get("topic")
            for p in (OUTPUT / cfg["_name"]).glob("*/plan.json")} if (OUTPUT / cfg["_name"]).exists() else set()
    tf = cfg["_dir"] / "topics.txt"
    for line in tf.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and line not in used:
            return line
    raise SystemExit("[오류] topics.txt 소재를 모두 썼습니다. 새 소재를 추가하거나 --topic 으로 지정하세요.")


def cmd_new(cfg: dict, topic: str | None) -> Path:
    topic = topic or _next_topic(cfg)
    print(f"[기획] {topic}")
    plan = plan_stage.mock_plan(cfg, topic)
    run_dir = OUTPUT / cfg["_name"] / f"{datetime.now():%Y%m%d-%H%M%S}-{_slug(topic)}"
    run_dir.mkdir(parents=True)
    (run_dir / "plan.json").write_text(json.dumps(plan, ensure_ascii=False, indent=2), encoding="utf-8")
    plan_stage.write_script_md(plan, run_dir / "script.md")
    (run_dir / "status.json").write_text(json.dumps({"approved": False, "done": {}}, indent=2), encoding="utf-8")
    print(f"   → {run_dir}")
    print("   plan.json 을 Claude에게 다듬어 달라고 하거나 직접 고친 뒤:")
    print(f"   autotube approve {run_dir}")
    return run_dir


def cmd_approve(run_dir: Path) -> None:
    status = json.loads((run_dir / "status.json").read_text(encoding="utf-8"))
    status["approved"] = True
    (run_dir / "status.json").write_text(json.dumps(status, ensure_ascii=False, indent=2), encoding="utf-8")
    plan = pipeline.load_plan(run_dir)
    plan_stage.write_script_md(plan, run_dir / "script.md")
    print(f"[승인] {plan['title']} — 이제: autotube make {run_dir}")


def _approved_queue(cfg: dict) -> list[Path]:
    """승인됐고 아직 로컬에 업로드 기록 없는 편들 (오래된 것부터)."""
    base = OUTPUT / cfg["_name"]
    cands = []
    for d in sorted(base.glob("*/status.json")):
        st = json.loads(d.read_text(encoding="utf-8"))
        if st.get("approved") and not (d.parent / "youtube_id.txt").exists():
            cands.append(d.parent)
    return sorted(cands)


def _uploaded_titles_safe(cfg: dict) -> set[str]:
    """유튜브에 이미 올라간 제목(중복 방지). 인증 없거나 실패하면 빈 집합."""
    if cfg["engines"]["mode"] == "mock":
        return set()
    has_auth = (cfg["_dir"] / "token.json").exists() or (cfg["_dir"] / cfg["youtube"]["client_secret_file"]).exists()
    if not has_auth:
        return set()
    try:
        from .engines.youtube import uploaded_titles
        return uploaded_titles(cfg)
    except Exception as e:  # 인증/네트워크 문제면 그냥 진행 (업로드 단계가 또 거른다)
        print(f"   [알림] 기존 업로드 목록 조회 실패(무시): {e}")
        return set()


def _render_one(cfg: dict, run_dir: Path, yes: bool) -> None:
    print(f"[render] {run_dir}")
    pipeline.make(run_dir, cfg, yes=yes)
    from .stages import upload
    upload.run_stage(run_dir, pipeline.load_plan(run_dir), cfg)


def cmd_render(cfg: dict, yes: bool, episode: str | None = None, count: int = 1) -> None:
    """승인된 편 중 '아직 유튜브에 없는' 가장 오래된 것부터 count 편을 만든다.
    episode 를 주면 그 폴더만 만든다."""
    if episode:
        run_dir = OUTPUT / cfg["_name"] / episode
        if not (run_dir / "plan.json").exists():
            raise SystemExit(f"[오류] 그런 편이 없습니다: {run_dir}")
        _render_one(cfg, run_dir, yes)
        return
    uploaded = _uploaded_titles_safe(cfg)
    picks = []
    for d in _approved_queue(cfg):
        if pipeline.load_plan(d)["title"][:100] in uploaded:
            continue
        picks.append(d)
        if len(picks) >= max(1, count):
            break
    if not picks:
        raise SystemExit(f"[오류] {cfg['_name']} 에 아직 안 올린 승인 편이 없습니다.")
    for d in picks:
        _render_one(cfg, d, yes)


def cmd_status(run_dir: Path) -> None:
    status = json.loads((run_dir / "status.json").read_text(encoding="utf-8"))
    print(f"승인: {status['approved']}")
    for stage in pipeline.MAKE_STAGES:
        print(f"  {'✓' if status['done'].get(stage) else '·'} {stage}")


def main() -> None:
    p = argparse.ArgumentParser(prog="autotube")
    sub = p.add_subparsers(dest="cmd", required=True)
    for name in ("new", "run"):
        sp = sub.add_parser(name)
        sp.add_argument("channel")
        sp.add_argument("--topic")
        sp.add_argument("--mock", action="store_true")
        sp.add_argument("--yes", action="store_true")
    rp = sub.add_parser("render")
    rp.add_argument("channel")
    rp.add_argument("--yes", action="store_true")
    rp.add_argument("--episode", default=None)
    rp.add_argument("--count", type=int, default=1)
    for name in ("approve", "make", "upload", "status"):
        sp = sub.add_parser(name)
        sp.add_argument("run_dir", type=Path)
        if name == "make":
            sp.add_argument("--yes", action="store_true")
    sub.add_parser("list")

    args = p.parse_args()
    load_env()

    if args.cmd == "list":
        for d in sorted(CHANNELS.glob("*/channel.yaml")):
            print(d.parent.name)
        return
    if args.cmd in ("new", "run"):
        cfg = load_channel(args.channel)
        if args.mock:
            cfg["engines"]["mode"] = "mock"
        run_dir = cmd_new(cfg, args.topic)
        if args.cmd == "run":
            cmd_approve(run_dir)
            pipeline.make(run_dir, cfg, yes=True)
            from .stages import upload
            upload.run_stage(run_dir, pipeline.load_plan(run_dir), cfg)
        return
    if args.cmd == "render":
        if args.channel == "all":
            names = [d.parent.name for d in sorted(CHANNELS.glob("*/channel.yaml"))]
            for name in names:
                try:
                    cmd_render(load_channel(name), yes=args.yes)
                except SystemExit as e:
                    print(f"[{name}] 건너뜀: {e}")
        else:
            cmd_render(load_channel(args.channel), yes=args.yes, episode=args.episode, count=args.count)
        return

    # approve/make/upload/status 는 폴더에서 채널명을 역산
    run_dir = args.run_dir
    channel = run_dir.resolve().parent.name
    cfg = load_channel(channel)
    if args.cmd == "approve":
        cmd_approve(run_dir)
    elif args.cmd == "make":
        pipeline.make(run_dir, cfg, yes=args.yes)
    elif args.cmd == "upload":
        from .stages import upload
        upload.run_stage(run_dir, pipeline.load_plan(run_dir), cfg)
    elif args.cmd == "status":
        cmd_status(run_dir)


if __name__ == "__main__":
    main()
