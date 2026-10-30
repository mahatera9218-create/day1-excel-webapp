"""실행 진입점.

  python -m autotube run --topic "주제"     기획 → 영상 생성 → 합치기 → 업로드 (한 번에)
  python -m autotube run --mock            비용 없이 가짜 영상으로 전체 흐름 시험
  python -m autotube plan --topic "주제"    대본(기획안)만 만들기
  python -m autotube render <폴더>          기획안으로 클립 생성 (중간에 끊겨도 이어서 진행)
  python -m autotube assemble <폴더>        클립 합치기 + 자막
  python -m autotube upload <폴더>          유튜브 업로드
"""

import argparse
import json
import re
from datetime import datetime
from pathlib import Path

from .config import ROOT, load_config, load_env, require_env

OUTPUT = ROOT / "output"


def _slug(text: str) -> str:
    return re.sub(r"[^\w가-힣]+", "-", text).strip("-")[:40]


def _next_topic() -> str:
    used = set()
    if OUTPUT.exists():
        for plan_file in OUTPUT.glob("*/plan.json"):
            used.add(json.loads(plan_file.read_text(encoding="utf-8")).get("topic"))
    topics_file = ROOT / "topics.txt"
    for line in topics_file.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and line not in used:
            return line
    raise SystemExit("[오류] topics.txt 의 주제를 모두 사용했습니다. 새 주제를 추가하거나 --topic 으로 지정해주세요.")


def _load_plan(run_dir: Path) -> dict:
    return json.loads((run_dir / "plan.json").read_text(encoding="utf-8"))


def cmd_plan(cfg, topic: str | None, mock: bool) -> Path:
    topic = topic or _next_topic()
    print(f"[1/4] 대본 작성: {topic}")
    if mock:
        plan = _mock_plan(topic)
    else:
        require_env("ANTHROPIC_API_KEY")
        from .script_writer import write_plan
        plan = write_plan(cfg, topic)
    run_dir = OUTPUT / f"{datetime.now():%Y%m%d-%H%M%S}-{_slug(topic)}"
    run_dir.mkdir(parents=True)
    (run_dir / "plan.json").write_text(json.dumps(plan, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"    제목: {plan['title']}")
    for i, s in enumerate(plan["scenes"], 1):
        print(f"    장면{i} ({s['duration']}초) {s['narration']}")
    print(f"    → {run_dir / 'plan.json'} (직접 고쳐도 됩니다)")
    return run_dir


def cmd_render(cfg, run_dir: Path, mock: bool, yes: bool) -> None:
    plan = _load_plan(run_dir)
    clips = run_dir / "clips"
    clips.mkdir(exist_ok=True)
    todo = [(i, s) for i, s in enumerate(plan["scenes"], 1) if not (clips / f"scene_{i:02}.mp4").exists()]
    if not todo:
        print("[2/4] 모든 클립이 이미 있습니다.")
        return

    if mock:
        from .pika import MockClient
        engine = MockClient(cfg)
    else:
        seconds = sum(s["duration"] for _, s in todo)
        cost = seconds * cfg["pika"]["price_per_second_usd"]
        print(f"[2/4] 영상 생성: {len(todo)}개 장면, 총 {seconds}초, 예상 비용 약 ${cost:.2f}")
        if cost > cfg["pika"]["max_cost_usd"]:
            raise SystemExit(f"[중단] 상한(max_cost_usd=${cfg['pika']['max_cost_usd']})을 넘습니다. config.yaml 에서 조정하세요.")
        if not yes and input("    진행할까요? (y/N) ").strip().lower() != "y":
            raise SystemExit("[중단] 취소했습니다.")
        from .pika import PikaClient
        engine = PikaClient(cfg, require_env("PIKA_API_KEY"))

    for i, scene in todo:
        print(f"    장면 {i}/{len(plan['scenes'])}")
        engine.render(scene, cfg, clips / f"scene_{i:02}.mp4")


def cmd_assemble(cfg, run_dir: Path) -> Path:
    print("[3/4] 합치기 + 자막")
    from .assemble import assemble
    final = assemble(run_dir, _load_plan(run_dir), cfg)
    print(f"    → {final}")
    return final


def cmd_upload(cfg, run_dir: Path) -> None:
    print(f"[4/4] 유튜브 업로드 ({cfg['youtube']['privacy']})")
    from .youtube import upload
    video_id = upload(run_dir / "final.mp4", _load_plan(run_dir), cfg)
    (run_dir / "youtube_id.txt").write_text(video_id, encoding="utf-8")
    print(f"    → https://youtu.be/{video_id}  (YouTube Studio 에서 확인 후 공개하세요)")


def _mock_plan(topic: str) -> dict:
    lines = ["이 영상은 시험용입니다.", "실제 API 를 부르지 않고 흐름만 확인합니다.", "자막과 합치기가 잘 되는지 보세요."]
    return {
        "topic": topic,
        "title": f"[테스트] {topic}",
        "description": "파이프라인 시험용 영상",
        "tags": ["test"],
        "scenes": [{"duration": 5, "narration": n, "shot": "test", "soundscape": "test", "music": "N/A"} for n in lines],
    }


def main() -> None:
    p = argparse.ArgumentParser(prog="autotube", description="AI 유튜브 영상 자동 제작")
    p.add_argument("--config", type=Path, help="설정 파일 (기본: config.yaml)")
    sub = p.add_subparsers(dest="cmd", required=True)

    run = sub.add_parser("run", help="기획부터 업로드까지 한 번에")
    run.add_argument("--topic")
    run.add_argument("--mock", action="store_true", help="API 없이 가짜 영상으로 시험")
    run.add_argument("--yes", action="store_true", help="비용 확인 질문 건너뛰기")
    run.add_argument("--no-upload", action="store_true", help="업로드 없이 final.mp4 까지만")

    plan = sub.add_parser("plan", help="대본만 만들기")
    plan.add_argument("--topic")
    plan.add_argument("--mock", action="store_true")

    render = sub.add_parser("render", help="클립 생성")
    render.add_argument("run_dir", type=Path)
    render.add_argument("--mock", action="store_true")
    render.add_argument("--yes", action="store_true")

    for name in ("assemble", "upload"):
        sub.add_parser(name).add_argument("run_dir", type=Path)

    args = p.parse_args()
    load_env()
    cfg = load_config(args.config)

    if args.cmd == "run":
        run_dir = cmd_plan(cfg, args.topic, args.mock)
        cmd_render(cfg, run_dir, args.mock, args.yes)
        cmd_assemble(cfg, run_dir)
        if args.no_upload or args.mock:
            print("업로드는 건너뛰었습니다. 확인 후: python -m autotube upload " + str(run_dir))
        else:
            cmd_upload(cfg, run_dir)
    elif args.cmd == "plan":
        cmd_plan(cfg, args.topic, args.mock)
    elif args.cmd == "render":
        cmd_render(cfg, args.run_dir, args.mock, args.yes)
    elif args.cmd == "assemble":
        cmd_assemble(cfg, args.run_dir)
    elif args.cmd == "upload":
        cmd_upload(cfg, args.run_dir)


if __name__ == "__main__":
    main()
