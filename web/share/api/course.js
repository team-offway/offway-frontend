// 공유 페이지가 코스를 읽어 가는 통로.
//
// 백엔드가 HTTPS(api.offway.cloud)를 받게 됐지만 CORS를 열어 주지는 않아,
// 브라우저가 직접 부르면 막힌다. 같은 출처로 여기까지 받아 넘기고,
// 겸사겸사 캐싱도 얹는다.
const API_ORIGIN = process.env.API_ORIGIN ?? 'https://api.offway.cloud';

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
