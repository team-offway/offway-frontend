// 공유 페이지가 코스를 읽어 가는 통로.
//
// 페이지는 HTTPS로 뜨는데 백엔드는 HTTP만 받는다 — 브라우저가 그 요청을
// 혼합 콘텐츠로 막기 때문에 직접 부를 수 없다. 그래서 같은 출처(HTTPS)로
// 여기까지 받고, 서버끼리는 HTTP로 통신한다.
//
// 백엔드가 HTTPS를 지원하게 되면 이 함수는 지우고 페이지가 직접 불러도 된다.
const API_ORIGIN = process.env.API_ORIGIN ?? 'http://18.181.168.227:8080';

export default async function handler(req, res) {
  const { token } = req.query;

  if (typeof token !== 'string' || !token) {
    res.status(400).json({ error: 'token required' });
    return;
  }

  try {
    const upstream = await fetch(
      `${API_ORIGIN}/api/v1/public/courses/${encodeURIComponent(token)}`,
    );
    const body = await upstream.text();

    // 없는 코스(404)·만료(410)도 그대로 넘겨 페이지가 구분해 안내하게 한다
    res.status(upstream.status);
    res.setHeader('content-type', 'application/json; charset=utf-8');
    // 공유 링크는 같은 내용을 여러 사람이 연다 — 잠깐 캐싱해 서버 부담을 던다
    res.setHeader('cache-control', 'public, max-age=60, s-maxage=300');
    res.send(body);
  } catch {
    res.status(502).json({ error: 'upstream unavailable' });
  }
}
