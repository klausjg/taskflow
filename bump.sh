#!/bin/bash
# ==============================================================================
# bump.sh — Flow 시리즈 version.json 자동 업데이트 스크립트
# ------------------------------------------------------------------------------
# 사용법 (3가지):
#
#   ./bump.sh                       → 현재/다음 rev 확인만 (파일 수정 안 함)
#   ./bump.sh "<제목>"               → rev 를 자동으로 +1 하고 제목 설정 ← 추천
#   ./bump.sh <rev번호> "<제목>"      → rev 를 지정한 번호로 강제 설정
#
# 예시:
#   ./bump.sh
#   ./bump.sh "자동 팝업 도입"
#   ./bump.sh 10 "번호 점프가 필요할 때"
#
# 동작:
#   - rev 는 "현재 version.json 의 rev + 1" 로 자동 계산 (또는 지정값)
#   - releaseDate 를 오늘(KST) 로
#   - releaseTime 을 현재 시각(KST) 으로
#   - title 을 지정한 문자열로
#   - notes 는 건드리지 않음 (기존 값 유지)
#
# 요구사항: python3 (macOS 기본 설치됨)
# ==============================================================================

set -e

show_usage() {
  echo "사용법:"
  echo "  ./bump.sh                       → 현재/다음 rev 확인만"
  echo "  ./bump.sh \"<제목>\"               → rev 자동 +1 (추천)"
  echo "  ./bump.sh <rev번호> \"<제목>\"      → rev 강제 지정"
  echo ""
  echo "예시:"
  echo "  ./bump.sh"
  echo "  ./bump.sh \"자동 팝업 도입\""
  echo "  ./bump.sh 10 \"번호 점프가 필요할 때\""
}

# --- 0) version.json 존재 확인 -----------------------------------------------
if [ ! -f version.json ]; then
  echo "❌ 현재 폴더에 version.json 이 없어요."
  echo "   레포 루트(version.json 이 있는 폴더)에서 실행해야 합니다."
  echo "   현재 위치: $(pwd)"
  exit 1
fi

# --- 1) 현재 rev 읽기 --------------------------------------------------------
CURRENT_REV=$(python3 -c "import json; print(json.load(open('version.json'))['rev'])")

# --- 2) git 태그로 실제 최신 릴리스 번호 확인 (있을 때만) --------------------
LATEST_TAG_REV=""
if command -v git >/dev/null 2>&1 && [ -d .git ]; then
  LATEST_TAG=$(git tag -l 'rev-*' 2>/dev/null | sed 's/rev-//' | sort -n | tail -1)
  if [ -n "$LATEST_TAG" ]; then
    LATEST_TAG_REV="$LATEST_TAG"
  fi
fi

# --- 3) 인자가 없으면 "상태 확인" 모드 ---------------------------------------
if [ $# -eq 0 ]; then
  NEXT=$((CURRENT_REV + 1))
  echo "📊 현재 상태"
  echo "   version.json 의 rev: $CURRENT_REV"
  if [ -n "$LATEST_TAG_REV" ]; then
    echo "   최신 git 태그:        rev-$LATEST_TAG_REV"
    if [ "$CURRENT_REV" != "$LATEST_TAG_REV" ]; then
      echo "   ⚠️  version.json rev 와 최신 태그가 일치하지 않아요. 한 번 확인하세요."
    fi
  else
    echo "   최신 git 태그:        (아직 rev-* 태그가 없음)"
  fi
  echo ""
  echo "💡 다음에 ./bump.sh \"<제목>\" 을 실행하면 rev 는 $NEXT 이 됩니다."
  exit 0
fi

# --- 4) 인자 파싱 ------------------------------------------------------------
if [ $# -eq 1 ]; then
  # 자동 증가 모드
  TITLE="$1"
  REV=$((CURRENT_REV + 1))
  MODE="auto"
elif [ $# -eq 2 ]; then
  # 명시 모드
  REV="$1"
  TITLE="$2"
  MODE="explicit"
  if ! [[ "$REV" =~ ^[0-9]+$ ]]; then
    echo "❌ rev번호는 숫자여야 합니다. (입력값: \"$REV\")"
    echo ""
    show_usage
    exit 1
  fi
else
  show_usage
  exit 1
fi

# --- 5) 안전장치: 명시 모드에서 현재 rev 보다 작거나 같으면 확인 ------------
if [ "$MODE" = "explicit" ] && [ "$REV" -le "$CURRENT_REV" ]; then
  echo "⚠️  경고: 입력한 rev($REV) 이 현재 version.json 의 rev($CURRENT_REV) 보다 작거나 같아요."
  echo "   정말 진행할까요? (y/N): "
  read -r ANSWER
  if [ "$ANSWER" != "y" ] && [ "$ANSWER" != "Y" ]; then
    echo "중단했어요."
    exit 1
  fi
fi

# --- 6) 같은 번호의 git 태그가 이미 있으면 경고 ------------------------------
if [ -n "$LATEST_TAG_REV" ] && command -v git >/dev/null 2>&1 && [ -d .git ]; then
  if git tag -l "rev-$REV" | grep -q "^rev-$REV$"; then
    echo "⚠️  경고: 'rev-$REV' 라는 git 태그가 이미 존재합니다."
    echo "   Release 를 새로 만들려면 다른 번호를 써야 해요."
    echo "   그래도 version.json 만 덮어쓸까요? (y/N): "
    read -r ANSWER
    if [ "$ANSWER" != "y" ] && [ "$ANSWER" != "Y" ]; then
      echo "중단했어요."
      exit 1
    fi
  fi
fi

# --- 7) KST 기준 날짜/시간 ---------------------------------------------------
DATE=$(TZ=Asia/Seoul date +"%Y-%m-%d")
TIME=$(TZ=Asia/Seoul date +"%H:%M")

# --- 8) python 으로 JSON 안전하게 수정 ---------------------------------------
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

# --- 9) 결과 출력 ------------------------------------------------------------
echo ""
echo "✅ version.json 업데이트 완료"
echo "   이전 rev: $CURRENT_REV"
echo "   새 rev:   $REV   $([ "$MODE" = "auto" ] && echo '(자동 +1)' || echo '(수동 지정)')"
echo "   date:     $DATE"
echo "   time:     $TIME (KST)"
echo "   title:    $TITLE"
echo ""
echo "📌 다음 단계 (복붙해서 실행하세요):"
echo ""
echo "   git add version.json"
echo "   git commit -m \"chore: bump to rev $REV\""
echo "   git push"
echo ""
echo "   그 다음 GitHub 에서:"
echo "   → 태그 'rev-$REV' + 제목 + 본문 작성 → Publish"
echo ""
