#!/bin/bash
# ==============================================================================
# bump.sh — Flow 시리즈 version.json 자동 업데이트 스크립트
# ------------------------------------------------------------------------------
# 사용법:
#   ./bump.sh <rev번호> "<제목>"
#
# 예시:
#   ./bump.sh 3 "자동 팝업 도입"
#
# 동작:
#   - version.json 의 rev 를 지정한 번호로
#   - releaseDate 를 오늘(KST) 로
#   - releaseTime 을 현재 시각(KST) 으로
#   - title 을 지정한 문자열로
#   자동 업데이트합니다. (notes 는 건드리지 않음)
#
# 요구사항: python3 (macOS 기본 설치됨)
# ==============================================================================

set -e

# --- 0) 인자 개수 체크 -------------------------------------------------------
if [ $# -lt 2 ]; then
  echo "❌ 인자가 부족해요."
  echo ""
  echo "사용법: ./bump.sh <rev번호> \"<제목>\""
  echo "예시:   ./bump.sh 3 \"자동 팝업 도입\""
  exit 1
fi

REV="$1"
TITLE="$2"

# --- 1) rev 가 숫자인지 체크 -------------------------------------------------
if ! [[ "$REV" =~ ^[0-9]+$ ]]; then
  echo "❌ rev번호는 숫자여야 합니다. (입력값: \"$REV\")"
  exit 1
fi

# --- 2) version.json 이 존재하는지 체크 --------------------------------------
if [ ! -f version.json ]; then
  echo "❌ 현재 폴더에 version.json 이 없어요."
  echo "   이 스크립트는 레포 루트 (version.json 이 있는 폴더) 에서 실행해야 합니다."
  echo "   현재 위치: $(pwd)"
  exit 1
fi

# --- 3) KST 기준 오늘 날짜 / 현재 시각 ---------------------------------------
DATE=$(TZ=Asia/Seoul date +"%Y-%m-%d")
TIME=$(TZ=Asia/Seoul date +"%H:%M")

# --- 4) python 으로 JSON 안전하게 수정 ---------------------------------------
export BUMP_REV="$REV"
export BUMP_DATE="$DATE"
export BUMP_TIME="$TIME"
export BUMP_TITLE="$TITLE"

python3 - <<'PY'
import json, os, sys

path = "version.json"
try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception as e:
    print(f"❌ version.json 을 읽는 중 오류: {e}")
    sys.exit(1)

data["rev"]         = int(os.environ["BUMP_REV"])
data["releaseDate"] = os.environ["BUMP_DATE"]
data["releaseTime"] = os.environ["BUMP_TIME"]
data["title"]       = os.environ["BUMP_TITLE"]
if "notes" not in data:
    data["notes"] = ""

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY

# --- 5) 결과 출력 ------------------------------------------------------------
echo ""
echo "✅ version.json 업데이트 완료"
echo "   rev:   $REV"
echo "   date:  $DATE"
echo "   time:  $TIME (KST)"
echo "   title: $TITLE"
echo ""
echo "📌 다음 단계 (복붙해서 실행하세요):"
echo ""
echo "   git add version.json"
echo "   git commit -m \"chore: bump to rev $REV\""
echo "   git push"
echo ""
echo "   그 다음 GitHub 에서:"
echo "   https://github.com/klausjg/<레포이름>/releases/new"
echo "   → 태그 'rev-$REV' + 제목 + 본문 작성 → Publish"
echo ""
