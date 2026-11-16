import { json } from "../lib/skills.js";

const MAX_REPOS = 60;
const REPO_PATTERN = /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/;
const SUCCESS_TTL_MS = 6 * 60 * 60 * 1000;
const FAILURE_TTL_MS = 10 * 60 * 1000;
const REQUEST_TIMEOUT_MS = 5000;

type Entry = { stars: number | null; expiresAt: number };

// 함수 인스턴스가 살아 있는 동안만 유지되는 캐시. 응답 자체도 CDN 에 1시간 캐시된다.
const cache = new Map<string, Entry>();
let limitedUntil = 0;

type Lookup = { stars: number | null; limited: boolean };

async function lookup(repo: string, token: string | undefined): Promise<Lookup> {
  const now = Date.now();
  const hit = cache.get(repo);
  if (hit && hit.expiresAt > now) return { stars: hit.stars, limited: false };
  if (now < limitedUntil) return { stars: null, limited: true };

  const headers: Record<string, string> = {
    Accept: "application/vnd.github+json",
    "User-Agent": "skills-gui-relay",
    "X-GitHub-Api-Version": "2022-11-28",
  };
  if (token) headers.Authorization = `Bearer ${token}`;

  try {
    const response = await fetch(`https://api.github.com/repos/${repo}`, {
      headers,
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });
    if (response.status === 429 || (response.status === 403 && response.headers.get("x-ratelimit-remaining") === "0")) {
      const reset = Number(response.headers.get("x-ratelimit-reset"));
      limitedUntil = Number.isFinite(reset) && reset > 0 ? reset * 1000 : now + FAILURE_TTL_MS;
      return { stars: null, limited: true };
    }
    if (!response.ok) {
      cache.set(repo, { stars: null, expiresAt: now + FAILURE_TTL_MS });
      return { stars: null, limited: false };
    }
    const body = (await response.json()) as { stargazers_count?: unknown };
    const stars = typeof body.stargazers_count === "number" ? body.stargazers_count : null;
    cache.set(repo, { stars, expiresAt: now + (stars === null ? FAILURE_TTL_MS : SUCCESS_TTL_MS) });
    return { stars, limited: false };
  } catch {
    return { stars: null, limited: false };
  }
}

/**
 * GitHub 저장소 스타 수. `repos=owner/repo,owner/repo` (최대 60개).
 * 응답: { stars: { "owner/repo": 123 | null }, limited: boolean }
 * null 은 저장소가 없거나 조회하지 못한 것이다. limited 는 GitHub 요청 한도에 걸렸다는 뜻이다.
 */
export async function GET(request: Request): Promise<Response> {
  const raw = new URL(request.url).searchParams.get("repos") ?? "";
  const repos = [...new Set(raw.split(",").map((s) => s.trim()).filter(Boolean))];
  if (repos.length === 0) return json({ error: "repos가 필요합니다." }, 400);
  if (repos.length > MAX_REPOS) return json({ error: `repos는 최대 ${MAX_REPOS}개입니다.` }, 400);
  const bad = repos.find((r) => !REPO_PATTERN.test(r));
  if (bad !== undefined) return json({ error: `저장소 형식이 올바르지 않습니다: ${bad}` }, 400);

  const token = process.env.GITHUB_TOKEN || undefined;
  const results = await Promise.all(repos.map((repo) => lookup(repo, token)));

  const stars: Record<string, number | null> = {};
  repos.forEach((repo, i) => (stars[repo] = results[i].stars));
  const limited = results.some((r) => r.limited);

  // 한도에 걸린 응답은 CDN 에 오래 두지 않는다.
  const cacheControl = limited ? "s-maxage=60" : "s-maxage=3600, stale-while-revalidate=86400";
  return json({ stars, limited }, 200, { "Cache-Control": cacheControl });
}
