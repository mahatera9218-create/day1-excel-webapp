"""정지 그림 한 장을 천천히 움직이는 영상으로 만든다 (켄 번스 효과)."""

from pathlib import Path

from .util import run

FPS = 25


def ken_burns(image: Path, out: Path, duration: float, motion: str, size: tuple[int, int]) -> None:
    w, h = size
    frames = max(int(duration * FPS), 1)
    # 가장자리 흔들림을 막으려고 2배로 키운 뒤 zoompan 을 적용한다.
    base = f"scale={w*2}:{h*2}:force_original_aspect_ratio=increase,crop={w*2}:{h*2}"
    if motion == "kenburns_pan":
        # 좌→우로 천천히 이동하면서 살짝 확대
        z = "min(zoom+0.0008,1.15)"
        x = "(iw-iw/zoom)*on/%d" % frames
        y = "ih/2-(ih/zoom/2)"
    else:  # kenburns_in (기본): 중앙을 향해 천천히 확대
        z = "min(zoom+0.0012,1.2)"
        x = "iw/2-(iw/zoom/2)"
        y = "ih/2-(ih/zoom/2)"
    vf = (f"{base},zoompan=z='{z}':x='{x}':y='{y}':d={frames}:s={w}x{h}:fps={FPS},"
          f"format=yuv420p")
    run(["-loop", "1", "-t", f"{duration:.3f}", "-i", image, "-vf", vf,
         "-c:v", "libx264", "-preset", "medium", "-crf", "20", out])
