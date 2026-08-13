// 공유 페이지가 '사용 연차 일수'를 얻어 가는 통로.
//
// 코스 공개 조회 응답에는 연차 일수가 없어서, 여행 날짜로 서버에 계산을
// 맡긴다(평일에서 공휴일을 뺀 값). 이 API는 공개가 아니라 임시 Basic 게이트
// 뒤에 있어, 브라우저 대신 여기서 자격을 붙여 부른다.
//
// 게이트가 걷히면 BASIC_AUTH_* 없이도 그대로 동작한다.
const API_ORIGIN = process.env.API_ORIGIN ?? 'http://18.181.168.227:8080';
const BASIC_USER = process.env.BASIC_AUTH_USER;
const BASIC_PASS = process.env.BASIC_AUTH_PASS;

export default async function handler(req, res) {
  const { start, end } = req.query;

  // 날짜 형식만 통과시킨다 — 그대로 상류로 넘기는 값이다
  const isDate = (v) => typeof v === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(v);
  if (!isDate(start) || !isDate(end)) {
    res.status(400).json({ error: 'start, end required (YYYY-MM-DD)' });
    return;
  }

  const headers = { 'content-type': 'application/json' };
  if (BASIC_USER && BASIC_PASS) {
    const token = Buffer.from(`${BASIC_USER}:${BASIC_PASS}`).toString('base64');
    headers.authorization = `Basic ${token}`;
  }

  try {
    const upstream = await fetch(`${API_ORIGIN}/api/v1/leaves/available-time`, {
      method: 'POST',
      headers,
      // 연차 소모는 이동수단과 무관하지만 서버가 값을 요구한다
      body: JSON.stringify({ startDate: start, endDate: end, transport: 'CAR' }),
    });
    const body = await upstream.text();

    res.status(upstream.status);
    res.setHeader('content-type', 'application/json; charset=utf-8');
    // 같은 날짜 구간은 결과가 바뀌지 않는다 — 넉넉히 캐싱한다
    res.setHeader('cache-control', 'public, max-age=3600, s-maxage=86400');
    res.send(body);
  } catch {
    res.status(502).json({ error: 'upstream unavailable' });
  }
}
