# 교보문고 전자도서관 Ebook 캡처 스크립트 for MacOS

아이패드에서 필기하면서 보기 위한 MacOS용 교보문고 전자도서관/eBook 캡처 스크립트입니다.

> ⚠️ **주의사항**: 개인적인 학습 목적으로만 사용해주세요. 캡처한 내용을 공유하거나 배포하는 것은 저작권법 위반입니다.

## 필수 요구사항

- MacOS 운영체제
- [ImageMagick](https://imagemagick.org/) 설치 필요
  ```bash
  brew install imagemagick
  ```
- 교보문고 전자도서관 또는 교보eBook 앱 설치 (App Store)

## 사용 방법

교보문고 앱에서 캡처하고 싶은 책을 연 뒤, 두 방식 중 하나로 실행합니다.

### 플래그 모드 (CLI)

```bash
bin/ebook-capture --book "책이름" --pages auto --region auto --app 1
```

- `--pages`: 숫자 또는 `auto` — `auto`면 페이지 넘김이 멈추면(마지막 페이지) 자동 종료
- `--region`: `x y w h` 좌표, `auto` (전경 뷰어 창에서 자동 산출), 또는 저장한 프리셋 이름
- `--app`: `1` 또는 `library` (교보도서관) / `2` 또는 `ebook` (교보eBook)
- `--save-region 이름`: 이번 실행의 영역을 프리셋으로 저장, `--list-regions`로 조회
- 일부 플래그만 지정하면 나머지는 대화형으로 물어봅니다
- `bin/ebook-capture --help`로 전체 도움말 확인

### 대화형 모드 (기존 방식)

1. 터미널에서 스크립트를 실행합니다:
   ```bash
   ./run-script.sh
   ```
2. 프롬프트에 따라 다음 정보를 입력합니다:
   - 책 이름 (PDF 파일명으로 사용됨)
   - 총 페이지 수
   - 캡처 영역 좌표 (x y w h 형식)
     - x: 왼쪽에서의 거리
     - y: 위에서의 거리
     - w: 캡처할 영역의 너비
     - h: 캡처할 영역의 높이
   - 앱 선택 (1: 교보도서관, 2: 교보eBook)

4. 스크립트가 자동으로 페이지를 넘기면서 캡처를 진행합니다.
5. 캡처가 완료되면 현재 디렉토리에 PDF 파일이 생성됩니다.
    완성된 파일의 제목은 다음과 같습니다.
    - ebook_reader_(설정한 책 제목).pdf
    - Ex) ebook_reader_bookNameExample.pdf

## 테스트

개발/변경 시 두 계층의 E2E 테스트를 사용합니다:

```bash
bash test/smoke.sh       # 자동 (Preview 대역): 전체 실행 + Ctrl-C 부분 병합 검증
bash test/real-e2e.sh    # 반자동 (실제 교보 앱): 릴리스 전 확인 게이트
```

자세한 프로세스와 권한 설정은 [test/README.md](test/README.md)를 참고하세요.
