"""대본 구조 린트 — '열린 고리' 공장 규격을 기계적으로 검사한다.

승인(approve) 전에 자동으로 돌려서, 리텐션 뼈대가 빠진 편은 승인 자체가 막히게 한다.
의미(사실성 등)는 사람이 보지만, 구조는 여기서 강제한다.
"""

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


def lint_plan(plan: dict) -> tuple[list[str], list[str]]:
    """(errors, warnings). errors 가 있으면 승인 불가."""
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
        if s.get("is_key"):
            key_count += 1
        # 사실성 경고: 직접 인용부호가 보이면 '문서로 확인된 실제 인용인지' 점검 유도
        narr = s.get("narration") or ""
        if any(q in narr for q in ('"', "“", "”")):
            warnings.append(f"장면 {i}: 따옴표가 있습니다 — 실제로 문서화된 인용인지 확인(지어낸 대사 금지).")

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
