// 랜딩 캐러셀이 홈 화면의 큐레이션 링크('연차 쓰기 전, 확인해보세요')를
// 받아 가는 통로.
//
// 서버는 큐레이션을 홈 응답(`GET /api/v1/home`)에 실어 주고, 그 API 는 임시
// Basic 게이트 뒤라 브라우저가 직접 못 부른다. 여기서 자격을 붙여 받고
// **큐레이션 목록만** 추려 넘긴다 — 홈 응답의 나머지(추천 지역·장소)는
// 랜딩에 필요 없고, 내보낼 이유도 없다.
//
// 목록은 어드민이 바꿀 때만 달라지므로 넉넉히 캐싱한다. 게이트가 걷히면
// BASIC_AUTH_* 없이도 그대로 동작한다.
const API_ORIGIN = process.env.API_ORIGIN ?? 'https://api.offway.cloud';
const BASIC_USER = process.env.BASIC_AUTH_USER;
const BASIC_PASS = process.env.BASIC_AUTH_PASS;
const FETCH_TIMEOUT_MS = 4000;

function authHeaders() {
  const headers = { accept: 'application/json' };
  if (BASIC_USER && BASIC_PASS) {
    const token = Buffer.from(`${BASIC_USER}:${BASIC_PASS}`).toString('base64');
    headers.authorization = `Basic ${token}`;
  }
  return headers;
}

/** 화면이 쓰는 칸만 남긴다 — 서버가 필드를 더 실어도 그대로 새지 않게 */
function pick(link) {
  return {
    id: link?.id ?? null,
    title: typeof link?.title === 'string' ? link.title : '',
    chipText: typeof link?.chipText === 'string' ? link.chipText : '',
    description: typeof link?.description === 'string' ? link.description : '',
    linkUrl: typeof link?.linkUrl === 'string' ? link.linkUrl : '',
    thumbnailUrl: typeof link?.thumbnailUrl === 'string' ? link.thumbnailUrl : '',
  };
}

export default async function handler(req, res) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
  try {
    const upstream = await fetch(`${API_ORIGIN}/api/v1/home`, {
      headers: authHeaders(),
      signal: controller.signal,
    });
    if (!upstream.ok) {
      res.status(502).json({ error: `upstream ${upstream.status}` });
      return;
    }
    const body = await upstream.json();
    const links = Array.isArray(body?.data?.curatedLinks) ? body.data.curatedLinks : [];
    // 제목이나 주소가 없는 줄은 카드가 될 수 없다
    const curatedLinks = links.map(pick).filter((l) => l.title && l.linkUrl);

    res.status(200);
    res.setHeader('content-type', 'application/json; charset=utf-8');
    // 어드민이 바꿀 때만 달라진다 — CDN 에 한 시간, 그 뒤 하루는 옛 값을 내며 갱신
    res.setHeader('cache-control', 'public, max-age=300, s-maxage=3600, stale-while-revalidate=86400');
    res.send(JSON.stringify({ status: 200, data: { curatedLinks } }));
  } catch {
    res.status(502).json({ error: 'upstream unavailable' });
  } finally {
    clearTimeout(timer);
  }
}
