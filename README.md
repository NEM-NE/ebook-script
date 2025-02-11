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

1. 교보문고 앱에서 캡처하고 싶은 책을 엽니다.
2. 터미널에서 스크립트를 실행합니다:
   ```bash
   ./run-script.sh
   ```
3. 프롬프트에 따라 다음 정보를 입력합니다:
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
