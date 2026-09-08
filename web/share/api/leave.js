// 공유 페이지가 '사용 연차 일수'를 얻어 가는 통로.
//
// 코스 공개 조회 응답에는 연차 일수가 없어서 여행 날짜로 센다. 규칙은 서버의
// `AvailableTime.countLeaveDays`와 같다 — **구간의 평일에서 공휴일을 뺀 수**.
// (첫날 반차는 로그인한 소유자만 아는 값이라 여기서는 온종일로 친다 — 예전
// 프록시도 그렇게 보냈다)
//
// 예전에는 서버의 `POST /leaves/available-time`에 계산을 맡겼는데, 서버가
// 쓰기 요청을 로그인 토큰만 받게 바꾸면서(core #320) Basic 으로 부르는 이
// 함수는 403 이 됐고 뱃지가 조용히 빠졌다. 공휴일 목록(GET)은 Basic 으로
// 읽을 수 있으므로 그것만 받아 여기서 센다 — 서버를 바꾸지 않아도 된다.
//
// 게이트가 걷히면 BASIC_AUTH_* 없이도 그대로 동작한다.
const API_ORIGIN = process.env.API_ORIGIN ?? 'https://api.offway.cloud';
const BASIC_USER = process.env.BASIC_AUTH_USER;
const BASIC_PASS = process.env.BASIC_AUTH_PASS;
const FETCH_TIMEOUT_MS = 3000;

function authHeaders() {
  const headers = { accept: 'application/json' };
  if (BASIC_USER && BASIC_PASS) {
    const token = Buffer.from(`${BASIC_USER}:${BASIC_PASS}`).toString('base64');
    headers.authorization = `Basic ${token}`;
  }
  return headers;
}

/** 그 해의 공휴일(`YYYY-MM-DD`) 집합 — 못 받으면 null */
async function fetchHolidays(year) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
  try {
    const upstream = await fetch(`${API_ORIGIN}/api/v1/holidays?year=${year}`, {
      headers: authHeaders(),
      signal: controller.signal,
    });
    if (!upstream.ok) return null;
    const body = await upstream.json();
    const dates = body?.data?.dates;
    return Array.isArray(dates) ? new Set(dates) : null;
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

/** 날짜 문자열을 UTC 자정으로 — 시간대에 따라 하루가 밀리지 않게 */
function utcDate(text) {
  const [y, m, d] = text.split('-').map(Number);
  return new Date(Date.UTC(y, m - 1, d));
}

function isoDate(date) {
  return date.toISOString().slice(0, 10);
}

/**
 * 구간의 소모 연차 — 주말·공휴일을 뺀 날 수 (서버 `AvailableTime`과 같은 규칙).
 * @param {Set<string>} holidays
 */
export function countLeaveDays(start, end, holidays) {
  let leave = 0;
  for (let day = utcDate(start); day <= utcDate(end); day.setUTCDate(day.getUTCDate() + 1)) {
    const weekday = day.getUTCDay(); // 0 일 · 6 토
    if (weekday === 0 || weekday === 6 || holidays.has(isoDate(day))) continue;
    leave += 1;
  }
  return leave;
}

export default async function handler(req, res) {
  const { start, end } = req.query;

  const isDate = (v) => typeof v === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(v);
  if (!isDate(start) || !isDate(end) || start > end) {
    res.status(400).json({ error: 'start, end required (YYYY-MM-DD, start <= end)' });
    return;
  }

  // 구간이 해를 넘기면 두 해의 공휴일이 필요하다 (12/31 → 1/2)
  const startYear = Number(start.slice(0, 4));
  const endYear = Number(end.slice(0, 4));
  const holidays = new Set();
  for (let year = startYear; year <= endYear; year += 1) {
    const dates = await fetchHolidays(year);
    if (dates === null) {
      // 공휴일을 모르면 평일만 세서 틀린 숫자를 내느니 뱃지를 안 붙인다
      res.status(502).json({ error: 'holidays unavailable' });
      return;
    }
    for (const date of dates) holidays.add(date);
  }

  res.status(200);
  res.setHeader('content-type', 'application/json; charset=utf-8');
  // 같은 날짜 구간은 결과가 바뀌지 않는다 — 넉넉히 캐싱한다
  res.setHeader('cache-control', 'public, max-age=3600, s-maxage=86400');
  // 공유 페이지가 읽는 모양은 예전 서버 응답과 같다 (`data.consumedLeaveDays`)
  res.send(JSON.stringify({ status: 200, data: { consumedLeaveDays: countLeaveDays(start, end, holidays) } }));
}
