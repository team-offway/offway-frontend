# 코스 공유 웹페이지

앱에서 복사한 링크(`/c/{shareToken}`)를 열면 보이는 **보기 전용** 페이지입니다.
계정이 없는 사람도 코스를 볼 수 있어야 해서, 인증 없는 공개 API만 씁니다.

파일 세 개뿐입니다 — 빌드 도구도, 의존성도 없습니다.

| 파일 | 하는 일 |
|---|---|
| `index.html` | 주소에서 토큰을 꺼내 코스를 읽고 일정을 그린다 |
| `api/course.js` | 백엔드로 넘겨주는 통로 (아래 참고) |
| `vercel.json` | `/c/:token` 을 `index.html` 로 넘긴다 |

## 왜 API를 직접 안 부르나

이 페이지는 HTTPS 로 뜨는데 **백엔드는 HTTP 만 받는다**. 브라우저는 HTTPS 문서가
HTTP 로 보내는 요청을 혼합 콘텐츠로 막기 때문에, 직접 부르면 배포된 링크가
코스를 못 불러온다.

그래서 같은 출처(HTTPS)의 서버리스 함수 `api/course.js` 로 한 번 받고,
서버끼리는 HTTP 로 통신한다. 부수 효과로 백엔드 주소가 브라우저에 드러나지 않는다.

백엔드가 HTTPS 를 지원하게 되면 이 함수를 지우고 페이지가 직접 불러도 된다.
서버 주소를 바꿔야 하면 Vercel 환경변수 `API_ORIGIN` 을 쓴다.

## 서버 쪽은 준비되어 있다

- `GET /api/v1/public/courses/{shareToken}` — **인증 불필요**. 임시 Basic 게이트에도 예외 처리돼 있다
- CORS 가 `https://offway-share.vercel.app` 을 허용한다

CORS 는 브라우저가 직접 부를 때만 걸리는데 지금은 서버리스 함수를 거치므로
프로젝트 이름이 달라도 동작한다. 다만 나중에 페이지가 API 를 직접 부르게 되면
그때는 이름이 맞아야 하므로, 특별한 이유가 없으면 `offway-share` 로 두는 게 낫다.

## 배포 방법

별도 레포를 만들 필요는 없다 — Vercel이 모노레포의 하위 폴더를 루트로 지정해 배포한다.

1. [vercel.com](https://vercel.com) → **Add New Project** → `offway-frontend` 선택
2. **Root Directory**: `web/share`
3. **Framework Preset**: Other (빌드 명령 없음)
4. **Project Name**: `offway-share`
5. Deploy

Flutter 코드만 바꿔도 재배포가 도는 게 신경 쓰이면,
Settings → Git → **Ignored Build Step** 에 아래를 넣는다.

```bash
git diff --quiet HEAD^ HEAD -- .
```

## 배포한 뒤 앱에 반영

앱이 만드는 링크 주소를 실제 도메인으로 바꾼다.

```bash
flutter run --dart-define=SHARE_BASE_URL=https://offway-share.vercel.app
```

늘 쓰는 값이면 `lib/core/config/app_config.dart` 의 `shareBaseUrl` 기본값을 바꾼다.
지금 기본값(`https://offway.app`)은 **등록되지 않은 도메인**이라 링크가 열리지 않는다.

## 알아둘 점

- 페이지가 백엔드 주소(`18.181.168.227:8080`)를 직접 부른다. 개발자도구에 드러나지만
  어차피 인증 없는 공개 API라 실질적 위험은 낮다. 가리려면 Vercel 서버리스 함수로 감싼다
- 서버 주소는 `index.html` 상단 `API` 상수 한 곳에 있다
- 응답에 코스 이름이 없어 **첫 장소의 `regionName`** 으로 제목을 만든다
