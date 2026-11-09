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

            # 이미지: 기본 Pika, "comfy"/"local" 이면 본인 GPU(ComfyUI/SDXL) — 추가 비용 0.
            # ★ 클라우드(GitHub)는 channel.yaml 그대로 pika, 로컬 PC 는 AUTOTUBE_IMAGE_ENGINE=comfy 로만 전환.
            img_engine = (os.environ.get("AUTOTUBE_IMAGE_ENGINE")
                          or cfg["engines"].get("image") or "pika").lower()
            if img_engine in ("comfy", "local"):
                from .local import LocalComfyEngine
                self._i = LocalComfyEngine(cfg)
            elif self._m is not None:
                self._i = self._m          # Pika 가 이미지도 담당(키 재사용)
            else:
                from .pika import PikaEngine
                self._i = PikaEngine(cfg, os.environ["PIKA_API_KEY"])  # 명시적 에러 유도

    def voice(self, scene, out):
        return self._v.voice(scene, out)

    def image(self, scene, out):
        return self._i.image(scene, out)

    def video(self, scene, image, out, duration):
        if self._m is None:
            raise RuntimeError("모션 엔진(Pika) 키가 없습니다 — 이 장면은 스틸로 폴백합니다.")
        return self._m.video(scene, image, out, duration)
