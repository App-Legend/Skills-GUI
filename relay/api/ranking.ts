import { json, parseInteger, proxySkills } from "../lib/skills.js";

const UPSTREAM_URL = "https://skills.sh/api/v1/skills";
const VIEWS = ["all-time", "trending", "hot"] as const;
const MAX_PER_PAGE = 500;

export async function GET(request: Request): Promise<Response> {
  const params = new URL(request.url).searchParams;
  const upstream = new URL(UPSTREAM_URL);

  const view = params.get("view");
  if (view !== null) {
    if (!(VIEWS as readonly string[]).includes(view)) {
      return json({ error: "view는 all-time, trending, hot 중 하나여야 한다." }, 400);
    }
    upstream.searchParams.set("view", view);
  }

  const page = params.get("page");
  if (page !== null) {
    const n = parseInteger(page);
    if (n === null || n < 0) {
      return json({ error: "page는 0 이상의 정수여야 한다." }, 400);
    }
    upstream.searchParams.set("page", String(n));
  }

  const perPage = params.get("per_page");
  if (perPage !== null) {
    const n = parseInteger(perPage);
    if (n === null || n < 1 || n > MAX_PER_PAGE) {
      return json({ error: `per_page는 1~${MAX_PER_PAGE} 사이의 정수여야 한다.` }, 400);
    }
    upstream.searchParams.set("per_page", String(n));
  }

  return proxySkills(upstream);
}
