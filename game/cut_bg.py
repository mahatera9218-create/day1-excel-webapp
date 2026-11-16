"""캐릭터 이미지 배경을 rembg(AI)로 깔끔하게 제거 → 투명 PNG(game/cut/).
GitHub Actions 에서 실행(모델 다운로드 필요). 게임 장면에 캐릭터가 자연스럽게 서게 한다.
"""
import glob
from pathlib import Path

from PIL import Image
from rembg import remove, new_session

HERE = Path(__file__).resolve().parent
OUT = HERE / "cut"
OUT.mkdir(parents=True, exist_ok=True)


def trim(im):
    """투명 여백 잘라내기 → 캐릭터만 꽉 차게."""
    bbox = im.getbbox()
    return im.crop(bbox) if bbox else im


def main():
    sess = new_session("u2net")
    srcs = sorted(glob.glob(str(HERE / "cast" / "*.png"))) + sorted(glob.glob(str(HERE / "npc" / "*.png")))
    for src in srcs:
        dest = OUT / Path(src).name
        if dest.exists():
            print(f"[skip] {dest.name}")
            continue
        print(f"[cut ] {dest.name}")
        im = Image.open(src).convert("RGBA")
        out = remove(im, session=sess, post_process_mask=True)
        out = trim(out)
        out.save(dest)
    print("완료:", len(list(OUT.glob("*.png"))), "장")


if __name__ == "__main__":
    main()
