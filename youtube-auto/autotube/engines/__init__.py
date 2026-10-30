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
            from .elevenlabs import ElevenLabsEngine
            from .pika import PikaEngine
            self._v = ElevenLabsEngine(cfg, os.environ["ELEVENLABS_API_KEY"])
            self._i = self._m = PikaEngine(cfg, os.environ["PIKA_API_KEY"])

    def voice(self, scene, out):
        return self._v.voice(scene, out)

    def image(self, scene, out):
        return self._i.image(scene, out)

    def video(self, scene, image, out, duration):
        return self._m.video(scene, image, out, duration)
