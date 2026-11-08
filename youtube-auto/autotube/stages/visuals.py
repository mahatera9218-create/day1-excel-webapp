"""그림: 장면마다 그림 1장. motion 이 video 인 장면은 그림을 움직이는 영상으로도 변환.

속도: 생성이 필요한 그림들은 스레드풀로 "동시에" 만든다(Pika는 I/O 대기라 병렬이 큰 이득).
재활용으로 토큰·크레딧도 아낀다:
- scene["image_ref"]: 같은 편의 '이전 장면 번호' 그림을 그대로 재사용(생성 0회).
- scene["image_lib"]: 채널 공용 라이브러리(channels/<ch>/assets_library/<key>.*)를 재사용.
"""

import json
import shutil
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from ..engines import Engines

_LIB_EXTS = (".png", ".jpg", ".jpeg", ".webp")
MAX_WORKERS = 6  # Pika 동시 요청 수


def library_file(cfg: dict, key: str) -> Path | None:
    base = cfg["_dir"] / "assets_library"
    for ext in _LIB_EXTS:
        p = base / f"{key}{ext}"
        if p.exists():
            return p
    return None


def run(run_dir: Path, plan: dict, cfg: dict) -> None:
    engines = Engines(cfg)
    style = cfg["visual_style"].strip()
    images = run_dir / "images"
    clips = run_dir / "clips"
    images.mkdir(exist_ok=True)
    clips.mkdir(exist_ok=True)
    timing = json.loads((run_dir / "timing.json").read_text(encoding="utf-8"))
    n = len(plan["scenes"])

    gen, reuse = [], []  # 생성 필요 / 재활용(복사)
    for i, scene in enumerate(plan["scenes"], 1):
        png = images / f"scene_{i:02}.png"
        if png.exists():
            continue
        ref = scene.get("image_ref")
        lib = scene.get("image_lib")
        if ref:
            reuse.append((i, scene, png, images / f"scene_{int(ref):02}.png"))
        elif lib and library_file(cfg, str(lib)):
            reuse.append((i, scene, png, library_file(cfg, str(lib))))
        else:
            gen.append((i, scene, png))

    # 1) 생성이 필요한 그림들을 동시에
    def _one(task):
        i, scene, png = task
        print(f"      장면 {i}/{n} 그림 생성")
        engines.image({**scene, "_label": f"#{i}", "_style": style}, png)

    if gen:
        workers = 1 if cfg["engines"]["mode"] == "mock" else min(MAX_WORKERS, len(gen))
        with ThreadPoolExecutor(max_workers=workers) as ex:
            list(ex.map(_one, gen))

    # 2) 재활용(복사) — 생성이 끝난 뒤라 image_ref 대상이 존재
    for i, scene, png, src in reuse:
        if src.exists():
            print(f"      장면 {i}/{n} 그림 재활용 ← {src.name}")
            shutil.copyfile(src, png)
        else:  # 폴백: 참조가 없으면 직접 생성
            print(f"      장면 {i}/{n} 재활용 실패 → 생성")
            engines.image({**scene, "_label": f"#{i}", "_style": style}, png)

    # 3) 영상 변환(motion==video)인 장면만 (드묾)
    for i, scene in enumerate(plan["scenes"], 1):
        if scene.get("motion") != "video":
            continue
        clip = clips / f"scene_{i:02}.mp4"
        if clip.exists():
            continue
        dur = timing[f"{i:02}"]["duration"]
        print(f"      장면 {i} 영상 변환 ({dur:.1f}초)")
        try:
            engines.video({**scene, "_label": f"#{i}", "_style": style},
                          images / f"scene_{i:02}.png", clip, dur)
        except Exception as e:  # noqa: BLE001 — 영상 변환 실패가 전체 렌더를 죽이지 않게(그 장면은 스틸+켄번스로 폴백)
            clip.unlink(missing_ok=True)
            print(f"      [경고] 장면 {i} 영상 변환 실패 → 스틸로 대체: {e}")
