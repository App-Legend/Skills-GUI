import { json, parseInteger, proxySkills } from "../lib/skills.js";

const UPSTREAM_URL = "https://skills.sh/api/v1/skills/search";
const MIN_QUERY_LENGTH = 2;
const MAX_LIMIT = 200;

/** skills.sh 검색. 한 단어는 이름 위주(fuzzy), 여러 단어는 의미 검색(semantic)이다. */
export async function GET(request: Request): Promise<Response> {
  const params = new URL(request.url).searchParams;
  const upstream = new URL(UPSTREAM_URL);

  const q = (params.get("q") ?? "").trim();
  if (q.length < MIN_QUERY_LENGTH) {
    return json({ error: `검색어는 ${MIN_QUERY_LENGTH}자 이상이어야 합니다.` }, 400);
  }
  upstream.searchParams.set("q", q);

  const limit = params.get("limit");
  if (limit !== null) {
    const n = parseInteger(limit);
    if (n === null || n < 1 || n > MAX_LIMIT) {
      return json({ error: `limit는 1~${MAX_LIMIT} 사이의 정수여야 합니다.` }, 400);
    }
    upstream.searchParams.set("limit", String(n));
  }

  return proxySkills(upstream);
}
