import { getVercelOidcToken } from "@vercel/oidc";

const UPSTREAM_URL = "https://skills.sh/api/v1/skills";
const VIEWS = ["all-time", "trending", "hot"] as const;
const MAX_PER_PAGE = 500;
const PASSTHROUGH_STATUSES = new Set([429, 503]);

function json(body: unknown, status: number, extra: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8", ...extra },
  });
}

function parseInteger(value: string): number | null {
  return /^\d+$/.test(value) ? Number(value) : null;
}

export async function GET(request: Request): Promise<Response> {
  const params = new URL(request.url).searchParams;
  const upstream = new URL(UPSTREAM_URL);

  const view = params.get("view");
  if (view !== null) {
    if (!(VIEWS as readonly string[]).includes(view)) {
      return json({ error: "view는 all-time, trending, hot 중 하나여야 합니다." }, 400);
    }
    upstream.searchParams.set("view", view);
  }

  const page = params.get("page");
  if (page !== null) {
    const n = parseInteger(page);
    if (n === null || n < 1) {
      return json({ error: "page는 1 이상의 정수여야 합니다." }, 400);
    }
    upstream.searchParams.set("page", String(n));
  }

  const perPage = params.get("per_page");
  if (perPage !== null) {
    const n = parseInteger(perPage);
    if (n === null || n < 1 || n > MAX_PER_PAGE) {
      return json({ error: `per_page는 1~${MAX_PER_PAGE} 사이의 정수여야 합니다.` }, 400);
    }
    upstream.searchParams.set("per_page", String(n));
  }

  let response: Response;
  try {
    const token = await getVercelOidcToken();
    response = await fetch(upstream, {
      headers: { Authorization: `Bearer ${token}`, Accept: "application/json" },
    });
  } catch {
    return json({ error: "skills.sh 호출에 실패했습니다." }, 502);
  }

  if (response.status === 200) {
    return new Response(await response.text(), {
      status: 200,
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "s-maxage=300",
      },
    });
  }

  if (PASSTHROUGH_STATUSES.has(response.status)) {
    const headers: Record<string, string> = {};
    const retryAfter = response.headers.get("Retry-After");
    if (retryAfter !== null) headers["Retry-After"] = retryAfter;
    return json({ error: `skills.sh 가 ${response.status} 를 반환했습니다.` }, response.status, headers);
  }

  return json({ error: `skills.sh 응답 오류 (${response.status})` }, 502);
}
