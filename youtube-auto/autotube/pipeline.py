"""단계 진행·이어하기 관리. 각 단계는 결과를 저장하고, 끝난 단계는 다시 실행 시 건너뛴다."""

import json
from pathlib import Path

from .stages import compose, shorts, thumbnail, visuals, voice

MAKE_STAGES = ["voice", "visuals", "compose", "thumbnail", "shorts"]


def _status(run_dir: Path) -> dict:
    path = run_dir / "status.json"
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    return {"approved": False, "done": {}}


def _save_status(run_dir: Path, status: dict) -> None:
    (run_dir / "status.json").write_text(json.dumps(status, ensure_ascii=False, indent=2), encoding="utf-8")


def load_plan(run_dir: Path) -> dict:
    return json.loads((run_dir / "plan.json").read_text(encoding="utf-8"))


def estimate_cost(plan: dict, cfg: dict) -> float:
    e = cfg["engines"]
    n_img = len(plan["scenes"])
    n_vid = sum(1 for s in plan["scenes"] if s.get("motion") == "video")
    from .engines.base import estimate_seconds
    vid_sec = sum(min(15, max(5, round(estimate_seconds(s["narration"]))))
                  for s in plan["scenes"] if s.get("motion") == "video")
    return n_img * e["price_per_image_usd"] + vid_sec * e["price_per_video_second_usd"]


def make(run_dir: Path, cfg: dict, yes: bool = False) -> None:
    status = _status(run_dir)
    if not status.get("approved"):
        raise SystemExit(f"[중단] 아직 검토 승인 전입니다. script.md 확인 후: autotube approve {run_dir}")
    plan = load_plan(run_dir)

    if cfg["engines"]["mode"] != "mock" and not status["done"].get("voice"):
        cost = estimate_cost(plan, cfg)
        print(f"   예상 비용 약 ${cost:.2f} (그림·영상 기준, 목소리 별도)")
        if cost > cfg["engines"]["max_cost_usd"]:
            raise SystemExit(f"[중단] 상한 ${cfg['engines']['max_cost_usd']} 초과. channel.yaml 조정 필요.")
        if not yes and input("   진행할까요? (y/N) ").strip().lower() != "y":
            raise SystemExit("[중단] 취소했습니다.")

    runners = {
        "voice": lambda: voice.run(run_dir, plan, cfg),
        "visuals": lambda: visuals.run(run_dir, plan, cfg),
        "compose": lambda: compose.run_stage(run_dir, plan, cfg),
        "thumbnail": lambda: thumbnail.run_stage(run_dir, plan, cfg),
        "shorts": lambda: shorts.run_stage(run_dir, plan, cfg),
    }
    # 단계 건너뛰기는 각 단계가 '결과 파일이 이미 있으면 생략'하는 방식으로 처리한다.
    # (status 의 done 플래그에 의존하지 않으므로, 미디어가 없는 GitHub 환경에서도 새로 생성된다.)
    for stage in MAKE_STAGES:
        print(f"   [{stage}]")
        runners[stage]()
        status["done"][stage] = True
        _save_status(run_dir, status)
    print(f"   완성: {run_dir / 'final.mp4'}")
