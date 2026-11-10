"""로컬 ComfyUI(SDXL)로 이미지를 생성한다 — 본인 GPU, 추가 비용 0.

ComfyUI 서버가 떠 있어야 한다(기본 http://127.0.0.1:8188). local-render/render_once.ps1 가
렌더 전에 자동으로 ComfyUI 를 띄운다. 모션(image-to-video)은 이 엔진이 맡지 않는다 —
Pika 를 그대로 쓰거나(하이브리드), 키가 없으면 스틸+켄번스로 폴백한다.

channel.yaml:
  engines:
    image: comfy            # pika(기본) 대신 로컬
    comfy_url: http://127.0.0.1:8188     # (선택) 기본값
    comfy_ckpt: sd_xl_base_1.0.safetensors  # (선택) models/checkpoints 안의 파일명
    comfy_steps: 28         # (선택)
    comfy_cfg: 6.5          # (선택)
"""

import json
import os
import time
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

# local-render/comfy_sdxl_workflow.json (레포 루트 기준)
DEFAULT_WORKFLOW = Path(__file__).resolve().parents[2] / "local-render" / "comfy_sdxl_workflow.json"


class LocalComfyEngine:
    name = "comfy"

    def __init__(self, cfg: dict):
        e = cfg.get("engines", {})
        self.base = (e.get("comfy_url") or os.environ.get("COMFY_URL") or "http://127.0.0.1:8188").rstrip("/")
        self.ckpt = e.get("comfy_ckpt") or os.environ.get("COMFY_CKPT") or "RealVisXL_V4.0.safetensors"
        self.steps = int(e.get("comfy_steps", 30))
        self.cfg_scale = float(e.get("comfy_cfg", 5.5))
        self.neg = e.get("comfy_negative",
                         "text, watermark, signature, logo, blurry, lowres, deformed, "
                         "extra fingers, extra limbs, fused fingers, bad hands, bad anatomy, "
                         "mutated, melted face, distorted face, disfigured, jpeg artifacts, ugly")
        wf = e.get("comfy_workflow")
        self.wf_path = Path(wf) if wf else DEFAULT_WORKFLOW
        self.client_id = uuid.uuid4().hex

    def _post(self, path: str, data: dict) -> dict:
        req = urllib.request.Request(
            f"{self.base}{path}", data=json.dumps(data).encode(),
            headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read().decode())

    def _get(self, path: str) -> bytes:
        with urllib.request.urlopen(f"{self.base}{path}", timeout=120) as r:
            return r.read()

    def image(self, scene: dict, out: Path) -> None:
        prompt = f"{scene['image_prompt']} {scene.get('_style', '')}".strip()
        # 16:9 SDXL 권장 해상도 (8GB 에서도 무리 없음)
        w, h = 1344, 768
        try:
            wf = json.loads(self.wf_path.read_text(encoding="utf-8"))
        except FileNotFoundError:
            raise RuntimeError(f"ComfyUI 워크플로 파일이 없습니다: {self.wf_path}")

        # 노드 주입 (comfy_sdxl_workflow.json 의 id 규약: 3=KSampler 4=Checkpoint 5=Latent 6=pos 7=neg)
        wf["4"]["inputs"]["ckpt_name"] = self.ckpt
        wf["6"]["inputs"]["text"] = prompt
        wf["7"]["inputs"]["text"] = self.neg
        wf["5"]["inputs"]["width"] = w
        wf["5"]["inputs"]["height"] = h
        wf["3"]["inputs"]["seed"] = int.from_bytes(os.urandom(4), "big")
        wf["3"]["inputs"]["steps"] = self.steps
        wf["3"]["inputs"]["cfg"] = self.cfg_scale

        try:
            res = self._post("/prompt", {"prompt": wf, "client_id": self.client_id})
        except Exception as ex:  # noqa: BLE001
            raise RuntimeError(f"ComfyUI 에 연결 실패({self.base}). ComfyUI 가 떠 있나요? — {ex}")
        pid = res.get("prompt_id")
        if not pid:
            raise RuntimeError(f"ComfyUI 응답에 prompt_id 없음: {res}")

        deadline = time.time() + 600
        while time.time() < deadline:
            hist = json.loads(self._get(f"/history/{pid}").decode())
            if pid in hist:
                outputs = hist[pid].get("outputs", {})
                for node in outputs.values():
                    for img in node.get("images", []):
                        q = urllib.parse.urlencode({
                            "filename": img["filename"],
                            "subfolder": img.get("subfolder", ""),
                            "type": img.get("type", "output")})
                        Path(out).write_bytes(self._get(f"/view?{q}"))
                        return
                raise RuntimeError(f"ComfyUI 출력에 이미지가 없습니다: {outputs}")
            time.sleep(1.5)
        raise TimeoutError("ComfyUI 이미지 생성 시간 초과(600초)")
