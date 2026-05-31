"""
Gemma E4B 템플릿 분류 정확도 평가 스크립트 (Step 1)

사용법:
  # Ollama 실행 확인 후
  python scripts/eval/eval_gemma_classification.py

출력:
  - 항목별 F1 점수
  - 전체 정확도 (80% 목표)
  - unmatched 처리 정확도
"""

import json
import re
import requests
from pathlib import Path

OLLAMA_URL = "http://localhost:11434/api/generate"
MODEL = "gemma3:4b"
DATASET_PATH = Path(__file__).parent / "eval_dataset.json"
TEMPLATES = ["인부출역현황", "재고현황", "작업진행현황", "장비가동율현황"]


def classify_with_gemma(voice_raw: str) -> dict:
    prompt = f"""활성 템플릿: {json.dumps(TEMPLATES, ensure_ascii=False)}
음성 원문: "{voice_raw}"

각 템플릿 항목에 해당하는 내용을 분류하고,
자연스러운 보고 문장으로 정제하여 JSON으로만 반환하세요.
해당 내용이 없는 항목은 빈 문자열로, 어느 항목에도 해당되지 않는 내용은 "unmatched" 키에 넣으세요.
예시: {{"인부출역현황": "오늘 12명 출역", "재고현황": "", "작업진행현황": "", "장비가동율현황": "", "unmatched": ""}}
"""
    res = requests.post(
        OLLAMA_URL,
        json={"model": MODEL, "prompt": prompt, "stream": False},
        timeout=60,
    )
    res.raise_for_status()
    raw = res.json()["response"]

    # JSON 추출
    match = re.search(r"\{[\s\S]*\}", raw)
    if not match:
        return {}
    try:
        return json.loads(match.group(0))
    except json.JSONDecodeError:
        return {}


def score_item(predicted: str, expected: str) -> float:
    """단순 이진 점수: 둘 다 비어있거나 둘 다 채워져 있으면 1, 아니면 0"""
    pred_empty = not predicted.strip()
    exp_empty = not expected.strip()
    if pred_empty == exp_empty:
        return 1.0
    return 0.0


def evaluate():
    dataset = json.loads(DATASET_PATH.read_text(encoding="utf-8"))
    all_keys = TEMPLATES + ["unmatched"]
    scores = {k: [] for k in all_keys}

    print(f"{'ID':>4} | {'입력 (30자)':30} | {'결과':10}")
    print("-" * 60)

    for item in dataset:
        predicted = classify_with_gemma(item["voice_raw"])
        expected = item["expected"]

        row_scores = []
        for key in all_keys:
            s = score_item(
                predicted.get(key, ""),
                expected.get(key, ""),
            )
            scores[key].append(s)
            row_scores.append(s)

        avg = sum(row_scores) / len(row_scores)
        preview = item["voice_raw"][:30]
        print(f"{item['id']:>4} | {preview:30} | {avg:.0%}")

    print("\n=== 항목별 정확도 ===")
    total_scores = []
    for key in all_keys:
        avg = sum(scores[key]) / len(scores[key])
        total_scores.extend(scores[key])
        print(f"  {key:16}: {avg:.0%}")

    overall = sum(total_scores) / len(total_scores)
    print(f"\n전체 정확도: {overall:.0%} (목표: 80%+)")
    if overall >= 0.8:
        print("✅ 목표 달성")
    else:
        print("❌ 프롬프트 튜닝 필요 → Step 2 진행")


if __name__ == "__main__":
    evaluate()
