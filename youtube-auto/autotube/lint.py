"""대본 구조 린트 — '열린 고리' 공장 규격을 기계적으로 검사한다.

승인(approve) 전에 자동으로 돌려서, 리텐션 뼈대가 빠진 편은 승인 자체가 막히게 한다.
의미(사실성 등)는 사람이 보지만, 구조는 여기서 강제한다.
"""

import json
import re
from pathlib import Path

# 캐릭터 보이스(선택). 장면의 voice 에 이 별칭을 넣으면 인물 목소리로 읽힌다(edge 엔진).
# (드라마 강제는 없앴지만, 쓰고 싶으면 여전히 유효한 값이어야 한다.)
CHARACTER_VOICES = {"m1", "m2", "m3", "f1", "f2", "f3"}
# 상상 강도 두 단계 — 'wild'(과감하되 그럴듯) 와 'max'(거의 공상과학, 재미/충격 우선)를 1:1로.
WHATIF_INTENSITIES = {"wild", "max"}


def _recent_plans(run_dir, limit: int) -> list[dict]:
    """이 편보다 '이전'(폴더명=타임스탬프 사전순)인 형제 편들의 plan 을 최신순으로 limit개."""
    try:
        base = Path(run_dir).parent
        me = Path(run_dir).name
    except Exception:  # noqa: BLE001
        return []
    prior = sorted(p for p in base.glob("*/plan.json") if p.parent.name < me)
    out = []
    for p in prior[-limit:]:
        try:
            out.append(json.loads(p.read_text(encoding="utf-8")))
        except Exception:  # noqa: BLE001
            pass
    return out


# 장면 역할 — 대본 뼈대를 기계가 알아볼 수 있게 태깅한다.
ROLES = {
    "hook",          # 0~15초: 가장 충격적인 그림 + 질문/주장 (1번 장면)
    "setup",         # 누가·언제·뭐가 걸렸나
    "loop_q",        # 질문을 던진다 (열린 고리 시작)
    "loop_fake",     # 당대의 공식 설명 = '가짜 해결'
    "loop_problem",  # 그 설명을 깨는 증거/모순 = '문제'
    "loop_reveal",   # 고리를 닫는다 (답)
    "second_hook",   # 40% 지점 2차 훅 ("진짜 이상한 건 따로 있다")
    "turn",          # 전환(轉): 금지된/스캔들 진실 = 클라이맥스
    "payoff",        # 진짜 해결 / 결말
    "button",        # 마지막 여운 한 줄 (댓글·다음영상 유도)
    "context",       # 그 외 연결 장면
}

# 대륙 카테고리 — 발행을 여기에 맞춰 돌린다(특정 국가 편중 금지).
CONTINENTS = {"Asia", "Europe", "Americas", "Africa", "Oceania"}

# 쉬운 말 규칙: 역사학자·마니아가 쓸 법한 어려운 단어는 막는다(초등학생도 이해 가능해야).
# 더 쉬운 표현으로 풀어 쓰면 통과. (단어 경계로 검사, 대소문자 무시)
HARD_WORDS = {
    "feudal", "feudalism", "serf", "serfs", "serfdom", "vassal", "vassals",
    "aristocracy", "aristocratic", "aristocrat", "bourgeoisie", "proletariat",
    "malthusian", "mercantilism", "hegemony", "autocracy", "oligarchy",
    "abdicate", "abdication", "annexation", "annexed", "ratify", "ratified",
    "sovereignty", "excommunicate", "excommunicated", "indulgences", "secession",
    "suffrage", "regicide", "usurp", "usurped", "dynastic", "patronage",
    "dowry", "primogeniture", "schism", "theological", "mercantile",
}

# 쇼츠에서 결말을 흘리는 전형적 표현(경고). 티저는 결과를 말하면 안 된다.
SPOILER_WORDS = {
    "won", "lost", "winner", "loser", "winners", "losers", "defeated",
    "survived", "died", "killed", "verdict",
}
MAX_SENTENCE_WORDS = 28  # 쉬운 말 = 짧은 문장


def lint_plan(plan: dict, run_dir=None) -> tuple[list[str], list[str]]:
    """(errors, warnings). errors 가 있으면 승인 불가.
    run_dir 가 주어지면 '편 간 로테이션'(실화/만약 섞기·드라마 주기)도 강제한다."""
    errors: list[str] = []
    warnings: list[str] = []

    title = (plan.get("title") or "").strip()
    if not title:
        errors.append("title 이 비어 있습니다.")
    elif "|" not in title:
        errors.append("title 에 '제목 | 부제' 형식의 '|' 가 없습니다 (호기심 유발 헤드라인).")

    if not (plan.get("description") or "").strip():
        errors.append("description 이 비어 있습니다.")

    tags = plan.get("tags") or []
    if len(tags) < 5:
        errors.append(f"tags 가 {len(tags)}개뿐입니다. 최소 5개(검색 노출용).")

    if not (plan.get("thumbnail_prompt") or "").strip():
        errors.append("thumbnail_prompt 가 비어 있습니다. (이미지-우선 전용 썸네일은 필수)")

    # 니치: 그 편만의 '안 흔한 앵글' 한 줄이 반드시 있어야 한다.
    angle = (plan.get("angle") or "").strip()
    if not angle:
        errors.append("angle 이 비어 있습니다 — 이 편만의 '흔하지 않은 니치 앵글' 한 줄은 필수.")
    elif len(angle.split()) < 4:
        warnings.append("angle 이 너무 짧습니다 — 상식과 다른 지점을 구체적으로.")

    # 포맷: content_type = 'what_if'(사실 기반 가상) | 'true'(사실). what_if 는 라벨링 필수.
    ctype = plan.get("content_type", "true")
    if ctype not in ("what_if", "true"):
        errors.append(f"content_type '{ctype}' 이(가) 잘못됐습니다. 'what_if' 또는 'true'.")
    if ctype == "what_if" and not (plan.get("disclaimer") or "").strip():
        errors.append("what_if 편은 disclaimer(가상 시나리오 명시)가 필수입니다 — 신뢰·광고 안전.")
    if ctype == "what_if":
        wi = (plan.get("whatif_intensity") or "").strip().lower()
        if wi not in WHATIF_INTENSITIES:
            errors.append(
                "what_if 편은 whatif_intensity 가 'wild'(과감하되 그럴듯) 또는 'max'(거의 공상과학, "
                "재미/충격 우선) 여야 합니다 — 상상의 '결말'이 세야 합니다. 둘을 1:1로 번갈아 쓰세요.")

    # 대륙: 발행 로테이션용. 반드시 5개 중 하나.
    cont = plan.get("continent")
    if cont not in CONTINENTS:
        errors.append(f"continent '{cont}' 이(가) 잘못됐습니다. {sorted(CONTINENTS)} 중 하나.")

    # 쇼츠: 전용 티저 2편(그 자체로 완결된 훅+CTA). 본편 장면 그림을 재사용.
    nsc = len(plan.get("scenes") or [])
    shorts = plan.get("shorts") or []
    need = 2
    if len(shorts) < need:
        errors.append(f"shorts 가 {len(shorts)}개입니다. 전용 티저 {need}편이 필요합니다.")
    for si, sh in enumerate(shorts[:need], 1):
        snar = (sh.get("narration") or "").strip()
        if not snar:
            errors.append(f"쇼츠 {si}: narration 이 비어 있습니다.")
        if not (sh.get("title") or "").strip():
            errors.append(f"쇼츠 {si}: title(쇼츠 전용 제목)이 비어 있습니다.")
        if not (sh.get("description") or "").strip():
            errors.append(f"쇼츠 {si}: description(쇼츠 전용 설명)이 비어 있습니다.")
        shard = sorted({w for w in re.findall(r"[a-zA-Z]+", snar.lower()) if w in HARD_WORDS})
        if shard:
            errors.append(f"쇼츠 {si}: 어려운 단어 {shard} — 쉬운 말로.")
        srefs = sh.get("scenes") or []
        good = [r for r in srefs if isinstance(r, int) and 1 <= r <= nsc]
        if not good:
            errors.append(f"쇼츠 {si}: scenes(보여줄 본편 장면 번호 1~{nsc})가 없습니다/잘못됐습니다.")
        # 정답 흘림 경고(쇼츠는 절대 결말을 미리 말하면 안 됨)
        spoil = sorted({w for w in re.findall(r"[a-z']+", snar.lower()) if w in SPOILER_WORDS})
        if spoil:
            warnings.append(f"쇼츠 {si}: 정답을 흘릴 수 있는 표현 {spoil} — 결과/결말은 숨기세요(훅만).")

    # 두 쇼츠가 '같은 걸 두 번'이면 막는다 — 각도가 겹치면 유입이 안 는다(편집 판단을 기계로 백업).
    if len(shorts) >= 2:
        s0, s1 = shorts[0], shorts[1]
        lead0 = (s0.get("scenes") or [None])[0]
        lead1 = (s1.get("scenes") or [None])[0]
        if lead0 is not None and lead0 == lead1:
            errors.append("쇼츠 2개가 같은 장면으로 시작합니다 — 서로 다른 장면/각도로 여세요 "
                          "(하나는 전제, 하나는 중간의 기이한 디테일).")
        if (s0.get("title") or "").strip().lower() == (s1.get("title") or "").strip().lower():
            errors.append("쇼츠 2개의 제목이 동일합니다 — 각각 달라야 합니다.")
        wa = {w for w in re.findall(r"[a-z]+", (s0.get("narration") or "").lower()) if len(w) > 3}
        wb = {w for w in re.findall(r"[a-z]+", (s1.get("narration") or "").lower()) if len(w) > 3}
        if wa and wb and len(wa & wb) / len(wa | wb) >= 0.55:
            errors.append("쇼츠 2개 나레이션이 거의 같습니다 — 다른 각도로 새로 쓰세요.")

    scenes = plan.get("scenes") or []
    n = len(scenes)
    if not (20 <= n <= 34):
        errors.append(f"장면 수가 {n}개입니다. 규격은 20~34개(~5분, 8~10초마다 새 그림).")

    roles = []
    key_count = 0
    for i, s in enumerate(scenes, 1):
        if not (s.get("narration") or "").strip():
            errors.append(f"장면 {i}: narration 이 비어 있습니다.")
        ref = s.get("image_ref")
        if ref is not None and (not isinstance(ref, int) or ref < 1 or ref >= i):
            errors.append(f"장면 {i}: image_ref={ref} 는 '이전 장면 번호(1~{i-1})'여야 합니다.")
        # image_ref(이전 장면 재활용)면 프롬프트 불필요. 그 외(생성/라이브러리)는 프롬프트 필수(폴백).
        if ref is None and not (s.get("image_prompt") or "").strip():
            errors.append(f"장면 {i}: image_prompt 가 비어 있습니다 (또는 image_ref 로 재활용).")
        r = s.get("role")
        if r not in ROLES:
            errors.append(f"장면 {i}: role '{r}' 이(가) 규격 밖입니다. 허용: {sorted(ROLES)}")
        roles.append(r)
        # 드라마: 장면에 voice 를 지정했으면 허용된 별칭이어야 한다.
        v = s.get("voice")
        if v not in (None, "", "narrator") and v not in CHARACTER_VOICES:
            errors.append(f"장면 {i}: voice '{v}' 는 허용 밖입니다 (narrator 또는 m1~m3/f1~f3).")
        if s.get("is_key"):
            key_count += 1
        # 사실성 경고: 직접 인용부호가 보이면 '문서로 확인된 실제 인용인지' 점검 유도
        narr = s.get("narration") or ""
        if any(q in narr for q in ('"', "“", "”")):
            warnings.append(f"장면 {i}: 따옴표가 있습니다 — 실제로 문서화된 인용인지 확인(지어낸 대사 금지).")
        # 쉬운 말 규칙: 어려운 단어(전문용어) 차단
        words_lc = re.findall(r"[a-zA-Z]+", narr.lower())
        hard = sorted({w for w in words_lc if w in HARD_WORDS})
        if hard:
            errors.append(f"장면 {i}: 어려운 단어 {hard} — 초등학생도 알 쉬운 말로 풀어 쓰세요.")
        # 긴 문장 경고 (쉬운 말 = 짧은 문장)
        for sent in re.split(r"[.!?]+", narr):
            if len(sent.split()) > MAX_SENTENCE_WORDS:
                warnings.append(f"장면 {i}: 문장이 깁니다(>{MAX_SENTENCE_WORDS}단어) — 짧게 끊으세요.")
                break

    # ---- 뼈대 필수 요소 ----
    if scenes and roles[0] != "hook":
        errors.append("1번 장면의 role 이 'hook' 이어야 합니다 (첫 5초 훅).")
    if "second_hook" not in roles:
        errors.append("2차 훅(role='second_hook')이 없습니다 — 중간 이탈 방지(40% 지점).")
    if roles.count("loop_q") < 2:
        errors.append(f"열린 고리(role='loop_q')가 {roles.count('loop_q')}개입니다. 최소 2개(질문→미룸 구조).")
    if "turn" not in roles:
        errors.append("전환/클라이맥스(role='turn')가 없습니다.")
    if "payoff" not in roles:
        errors.append("결말(role='payoff')이 없습니다.")
    if scenes and roles[-1] != "button":
        errors.append("마지막 장면의 role 이 'button' 이어야 합니다 (여운 한 줄).")

    if not (4 <= key_count <= 6):
        errors.append(f"핵심 장면(is_key=true)이 {key_count}개입니다. 규격은 4~6개(그림 크레딧 집중).")

    # ---- 경고(막지는 않음) ----
    if "second_hook" in roles:
        frac = roles.index("second_hook") / max(1, n)
        if not (0.30 <= frac <= 0.55):
            warnings.append(f"2차 훅 위치가 {frac*100:.0f}% 입니다. 40%(30~55%) 부근 권장.")
    words = sum(len((s.get("narration") or "").split()) for s in scenes)
    if words and not (600 <= words <= 900):
        warnings.append(f"전체 {words}단어 — ~5분 목표면 700~800단어 권장.")

    # ---- 편 간 로테이션 강제(기획 DNA): 100% 만약(what_if) + 상상 강도 wild:max 1:1 ----
    if run_dir is not None:
        # (A) 이 채널은 100% '만약(what_if = 사실+공상)' — 실화 단독 편은 쓰지 않는다.
        if plan.get("content_type") != "what_if":
            errors.append(
                "이 채널은 100% '만약(what_if = 사실+공상)'입니다 — 이 편도 "
                "content_type='what_if'(분기점까지 사실 + 그 뒤 상상 + disclaimer)로 만드세요.")

        # (A2) 상상 강도 1:1 — 'wild'↔'max' 를 번갈아. 같은 tier 가 직전 2편과 같으면 막는다.
        tier = (plan.get("whatif_intensity") or "").strip().lower()
        prior_wif = [p for p in _recent_plans(run_dir, 6) if p.get("content_type") == "what_if"]
        last2 = [(p.get("whatif_intensity") or "").strip().lower() for p in prior_wif[-2:]]
        if tier in WHATIF_INTENSITIES and len(last2) == 2 and last2[0] == last2[1] == tier:
            other = "max" if tier == "wild" else "wild"
            errors.append(
                f"상상 강도 '{tier}' 가 3편 연속입니다 — 이 편은 '{other}'로 (wild↔max 를 1:1로 번갈아).")

    return errors, warnings


def format_report(errors: list[str], warnings: list[str]) -> str:
    out = []
    if errors:
        out.append("린트 실패 (승인 불가):")
        out += [f"  ✗ {e}" for e in errors]
    else:
        out.append("린트 통과 ✓ (구조 규격 충족)")
    if warnings:
        out.append("경고(확인 권장):")
        out += [f"  ! {w}" for w in warnings]
    return "\n".join(out)
