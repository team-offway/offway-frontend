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
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const API_ORIGIN = process.env.API_ORIGIN ?? 'https://api.offway.cloud';
const PAGES = { r: 'recommend.html', m: 'mycourse.html' };
const FETCH_TIMEOUT_MS = 3000;

/** 이 함수 파일이 있는 `api/`의 부모 — `includeFiles`가 HTML을 실어 두는 자리 */
const SITE_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');

/**
 * HTML 파일을 찾는다.
 *
 * **`process.cwd()`만 믿으면 안 된다.** 배포된 함수의 작업 디렉터리는 로컬과
 * 달라, 거기서 `recommend.html`을 열면 ENOENT로 함수가 통째로 죽었다
 * (500 FUNCTION_INVOCATION_FAILED). 파일은 함수 파일 위치를 기준으로
 * 찾는 게 어디서 돌든 같고, 그래도 없으면 cwd 도 한 번 본다.
 */
function findPage(file) {
  const candidates = [join(SITE_ROOT, file), join(process.cwd(), file)];
  const found = candidates.find((path) => existsSync(path));
  return { path: found ?? null, candidates };
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
  const page = findPage(file);
  if (!page.path) {
    // 죽지 말고 무엇을 못 찾았는지 남긴다 — 로그 없이 배포 환경의 경로를
    // 알 방법이 이것뿐이다. 미리보기 한 줄 때문에 페이지가 안 열리면 안 된다
    console.error('공유 페이지 HTML 을 찾지 못했습니다', page.candidates);
    res.status(500);
    res.setHeader('content-type', 'text/plain; charset=utf-8');
    res.send(`page not found: ${page.candidates.join(', ')}`);
    return;
  }
  const html = readFileSync(page.path, 'utf8');
  const course = typeof token === 'string' && token ? await fetchCourse(token) : null;

  res.status(200);
  res.setHeader('content-type', 'text/html; charset=utf-8');
  // 공유 링크는 같은 내용을 여러 사람이 연다 — api/course 와 같은 캐싱
  res.setHeader('cache-control', 'public, max-age=60, s-maxage=300');
  res.send(withRegion(html, regionNameOf(course)));
}
