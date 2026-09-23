"""Offway iOS 앱 아키텍처 다이어그램(.drawio) 생성기.

core 레포의 docs/architecture/gen_drawio.py 와 같은 스타일(점선 레인 · 브랜드 타일 ·
직각 화살표)을 쓴다. 스타일 함수와 Page 는 그 파일에서 가져온다.

다시 그리려면 (이 폴더에서):
  python3 icons.py                   # 아이콘을 바꿨을 때만 — icons.json 을 다시 굽는다
  python3 gen_app_architecture.py    # offway-app-architecture.drawio 생성
  python3 render.py . offway-app-architecture.drawio offway-app-architecture.png
                                     # draw.io 공식 뷰어로 PNG 를 뽑는다 (playwright · Chrome)
손으로 고칠 때는 .drawio 를 draw.io 에서 열어 수정한 뒤 PNG 로 내보내도 된다.

그리는 것: 앱 하나가 여러 곳으로 나뉘어 도는 모습 — Flutter 앱과 Swift 확장,
서버(HTTPS · FCM · APNs), 공유 웹, 로그인 · 지도 SDK. 서버 인프라는 core 그림이 맡는다.
"""

from gen_drawio import (EDGE, EDGE_BACK, LANE, Page, img_tile, lbl, note)

W, H = 1130, 1010


def page_app() -> Page:
    p = Page("Offway iOS 앱", W, H)

    # ── 레인
    login_lane = p.node(lbl("소셜 로그인"), 40, 40, 460, 140, LANE)
    p.node(lbl("iPhone · Offway 앱"), 40, 210, 460, 560, LANE)
    p.node(lbl("알림 · 푸시"), 560, 210, 200, 560, LANE)
    p.node(lbl("Offway 서버 · team-offway/core"), 820, 210, 240, 560, LANE)
    p.node(lbl("공유 웹 · Vercel"), 300, 810, 300, 170, LANE)

    # ── 소셜 로그인
    p.node(lbl("카카오"), 110, 88, 50, 50, img_tile("kakao"))
    p.node(lbl("Apple"), 225, 88, 50, 50, img_tile("apple"))
    p.node(lbl("Google"), 340, 88, 50, 50, img_tile("google"))

    # ── 기기 안
    app = p.node(lbl("Flutter 앱"), 100, 280, 66, 66, img_tile("flutter"))
    naver = p.node(lbl("네이버 지도 SDK"), 100, 500, 66, 66, img_tile("naver"))
    ext = p.node(lbl("Swift 확장", "위젯 · 잠금화면 ·", "다이나믹 아일랜드"),
                 340, 500, 66, 66, img_tile("swift"))

    # ── 알림 · 서버 · 웹
    apns = p.node(lbl("APNs"), 627, 500, 66, 66, img_tile("apple"))
    fcm = p.node(lbl("FCM"), 627, 640, 66, 66, img_tile("firebase"))
    api = p.node(lbl("REST API", "api.offway.cloud"), 898, 280, 66, 66, img_tile("springboot"))
    web = p.node(lbl("offway.cloud", "공유 코스 보기 · 약관"), 417, 850, 66, 66, img_tile("vercel"))

    # ── 화살표 — 코리더를 서로 다르게 잡아 겹치지 않게 한다
    p.edge(login_lane, app, lbl("소셜 토큰"), style=EDGE_BACK, exit_=(0.2, 1), entry=(0.5, 0))
    p.edge(app, naver, lbl("지도 렌더"), exit_=(0.5, 1), entry=(0.5, 0))
    p.edge(app, api, lbl("HTTPS · JWT"), exit_=(1, 0.25), entry=(0, 0.25))
    p.edge(app, ext, lbl("MethodChannel · App Group", "지역·날짜만 넘긴다"),
           exit_=(1, 0.75), entry=(0.5, 0))
    p.edge(api, apns, lbl("push-to-start · 갱신"), exit_=(0.25, 1), entry=(1, 0.5))
    p.edge(apns, ext, lbl("잠금화면 카드"), exit_=(0, 0.5), entry=(1, 0.5))
    p.edge(api, fcm, lbl("푸시"), exit_=(0.75, 1), entry=(1, 0.5))
    p.edge(fcm, app, lbl("여행 알림"), exit_=(0, 0.5), entry=(0, 0.75),
           points=[(80, 673), (80, 329.5)])
    p.edge(app, web, lbl("카카오톡 공유 · 링크"), exit_=(0, 0.25), entry=(0, 0.5),
           points=[(60, 296.5), (60, 883)])
    p.edge(web, api, lbl("서버를 대신 호출"), exit_=(1, 0.5), entry=(1, 0.5),
           points=[(1090, 883), (1090, 313)])
    return p


if __name__ == "__main__":
    from pathlib import Path
    page = page_app()
    xml = ('<mxfile host="app.diagrams.net" agent="offway-app-arch-gen" version="24.7.17">\n'
           + page.render(1) + "\n</mxfile>\n")
    out = Path(__file__).parent / "offway-app-architecture.drawio"
    out.write_text(xml, encoding="utf-8")
    print("생성:", out.name)
