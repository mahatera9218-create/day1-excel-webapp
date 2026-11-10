"""엔진 선택기: mock 모드면 가짜 엔진, real 모드면 실제 API 엔진을 돌려준다."""

import os


class Engines:
    """voice/image/video 를 적절한 엔진으로 연결한다."""

    def __init__(self, cfg: dict):
        self.cfg = cfg
        self.mode = cfg["engines"]["mode"]
        if self.mode == "mock":
            from .mock import MockEngine
            self._v = self._i = self._m = MockEngine(cfg)
        else:
            tts = cfg["engines"].get("tts", "edge")
            if tts == "elevenlabs":
                from .elevenlabs import ElevenLabsEngine
                self._v = ElevenLabsEngine(cfg, os.environ["ELEVENLABS_API_KEY"])
            else:  # edge: 무료 Microsoft TTS, 키 불필요
                from .edge import EdgeEngine
                self._v = EdgeEngine(cfg)

            # 모션(image-to-video)은 Pika. 키가 있을 때만 생성한다(없으면 모션 장면은 스틸 폴백).
            pika_key = os.environ.get("PIKA_API_KEY")
            if pika_key:
                from .pika import PikaEngine
                self._m = PikaEngine(cfg, pika_key)
            else:
                self._m = None

            # 이미지 엔진. 클라우드(GitHub)는 channel.yaml 그대로 pika, 로컬 PC 는 환경변수로 전환.
            #   pika  : 전부 Pika(유료, 고품질)
            #   comfy : 전부 로컬 SDXL/ComfyUI(공짜)
            #   mix   : 핵심 장면(is_key)·썸네일만 Pika, 나머진 로컬 → 품질은 필요한 데만, 비용 최소
            img_engine = (os.environ.get("AUTOTUBE_IMAGE_ENGINE")
                          or cfg["engines"].get("image") or "pika").lower()
            self._mix = False
            self._i_pika = None
            if img_engine in ("comfy", "local"):
                from .local import LocalComfyEngine
                self._i = LocalComfyEngine(cfg)
            elif img_engine == "mix":
                from .local import LocalComfyEngine
                self._i = LocalComfyEngine(cfg)   # 기본(자잘한 장면) = 로컬 공짜
                self._mix = True
                self._i_pika = self._m            # 핵심 장면 = Pika(키 있을 때만, 없으면 전부 로컬)
            elif self._m is not None:
                self._i = self._m          # Pika 가 이미지도 담당(키 재사용)
            else:
                from .pika import PikaEngine
                self._i = PikaEngine(cfg, os.environ["PIKA_API_KEY"])  # 명시적 에러 유도

    def voice(self, scene, out):
        return self._v.voice(scene, out)

    def image(self, scene, out):
        eng = self._i
        # mix: 핵심 장면(is_key)·썸네일(_label=='T')·명시 지정은 Pika, 나머진 로컬
        if self._mix and self._i_pika is not None:
            if scene.get("is_key") or scene.get("img_engine") == "pika" or scene.get("_label") == "T":
                eng = self._i_pika
        return eng.image(scene, out)

    def video(self, scene, image, out, duration):
        if self._m is None:
            raise RuntimeError("모션 엔진(Pika) 키가 없습니다 — 이 장면은 스틸로 폴백합니다.")
        return self._m.video(scene, image, out, duration)
