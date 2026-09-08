// 코스 공유 페이지의 HTML을 **지역 이름을 채워** 내려준다.
//
// 카톡·슬랙 미리보기는 JS를 안 돌린다. og:title에 "Offway 정선 추천코스"처럼
// 지역을 넣으려면 HTML 자체가 그렇게 나가야 해서, /r/·/m/ 주소를 이 함수가
// 받아 코스를 읽고 정적 HTML의 메타 자리를 바꿔 준다. 페이지의 나머지
// (지도·목록)는 지금처럼 브라우저가 /api/course 로 채운다.
//
// 코스를 못 읽거나 늦으면(3초) 지역 없이 원래 HTML을 그대로 낸다 —
// 미리보기 한 줄 때문에 페이지가 안 열리면 안 된다.
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const API_ORIGIN = process.env.API_ORIGIN ?? 'https://api.offway.cloud';
const PAGES = { r: 'recommend.html', m: 'mycourse.html' };
const FETCH_TIMEOUT_MS = 3000;

/**
 * HTML 파일이 있을 만한 자리들.
 *
 * **`import.meta.url`은 쓰지 않는다.** 이 폴더에 `package.json`이 없어 Vercel이
 * 함수를 CommonJS로 묶는데, 그 모드에서는 `import.meta`가 빈 값이라 모듈을
 * 읽는 순간 터진다 — 모든 요청이 500이 됐다(#249 뒤). `typeof __dirname`은
 * 두 모드 어디서도 안전하다: CommonJS면 함수 파일의 폴더고, ESM이면 undefined다.
 */
function pageCandidates(file) {
  const roots = [];
  // eslint-disable-next-line no-undef
  if (typeof __dirname === 'string') roots.push(join(__dirname, '..'));
  roots.push(process.cwd(), '/var/task');
  return roots.map((root) => join(root, file));
}

/**
 * 정적 HTML을 구한다 — 파일이 없으면 **자기 도메인에서 HTTP로** 받는다.
 *
 * 배포된 함수의 작업 디렉터리에는 `includeFiles`로 실은 HTML이 없었다
 * (`readFileSync`가 ENOENT로 함수를 죽였다). 번들이 파일을 어디에 두든
 * 정적 파일은 같은 도메인에서 늘 서비스되므로, 그쪽에서 받으면 구조와
 * 무관하게 동작한다. 캐시가 붙어 있어 비용도 작다.
 */
async function loadPage(file, host) {
  const candidates = pageCandidates(file);
  const found = candidates.find((path) => existsSync(path));
  if (found) return { html: readFileSync(found, 'utf8'), tried: candidates };
  if (host) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
    try {
      const upstream = await fetch(`https://${host}/${file}`, { signal: controller.signal });
      if (upstream.ok) return { html: await upstream.text(), tried: candidates };
    } catch {
      // 아래에서 못 찾았다고 답한다
    } finally {
      clearTimeout(timer);
    }
  }
  return { html: null, tried: candidates };
}

/** 코스 응답에서 지역 이름 — 앱과 같은 자리(첫 날 첫 칸의 regionName) */
export function regionNameOf(course) {
  for (const day of course?.days ?? []) {
    for (const item of day?.items ?? []) {
      if (typeof item?.regionName === 'string' && item.regionName.trim()) {
        return item.regionName.trim();
      }
    }
  }
  return '';
}

function escapeAttr(text) {
  return String(text)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/** og:title·og:image:alt 에 지역을 넣는다. 지역이 없으면 그대로 */
export function withRegion(html, region) {
  if (!region) return html;
  const title = `Offway ${escapeAttr(region)} 추천코스`;
  return html
    .replace(/(<meta property="og:title" content=")[^"]*(")/, `$1${title}$2`)
    .replace(/(<meta property="og:image:alt" content=")[^"]*(")/, `$1${title}$2`);
}

async function fetchCourse(token) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
  try {
    const upstream = await fetch(
      `${API_ORIGIN}/api/v1/public/courses/${encodeURIComponent(token)}`,
      { signal: controller.signal },
    );
    if (!upstream.ok) return null;
    const body = await upstream.json();
    return body?.data ?? null;
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

export default async function handler(req, res) {
  const { kind, token } = req.query;
  const file = PAGES[kind];
  if (!file) {
    res.status(404).send('not found');
    return;
  }
  const page = await loadPage(file, req.headers?.host);
  if (!page.html) {
    // 죽지 말고 무엇을 못 찾았는지 남긴다 — 로그 없이 배포 환경의 경로를
    // 알 방법이 이것뿐이다
    console.error('공유 페이지 HTML 을 찾지 못했습니다', page.tried);
    res.status(500);
    res.setHeader('content-type', 'text/plain; charset=utf-8');
    res.send(`page not found: ${page.tried.join(', ')}`);
    return;
  }
  const html = page.html;
  const course = typeof token === 'string' && token ? await fetchCourse(token) : null;

  res.status(200);
  res.setHeader('content-type', 'text/html; charset=utf-8');
  // 공유 링크는 같은 내용을 여러 사람이 연다 — api/course 와 같은 캐싱
  res.setHeader('cache-control', 'public, max-age=60, s-maxage=300');
  res.send(withRegion(html, regionNameOf(course)));
}
