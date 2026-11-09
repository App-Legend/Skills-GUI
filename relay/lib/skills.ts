import { getVercelOidcToken } from "@vercel/oidc";

const PASSTHROUGH_STATUSES = new Set([429, 503]);

export function json(body: unknown, status: number, extra: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8", ...extra },
  });
}

export function parseInteger(value: string): number | null {
  return /^\d+$/.test(value) ? Number(value) : null;
}

/**
 * skills.sh 를 Vercel OIDC 토큰으로 부르고 응답을 그대로 넘긴다.
 * 200 은 5분 캐시, 429·503 은 상태 그대로, 나머지 실패는 502.
 * notFoundMessage 를 주면 404 는 그 문구로 404 를 돌려준다.
 */
export async function proxySkills(
  upstream: URL,
  options: { notFoundMessage?: string } = {},
): Promise<Response> {
  let response: Response;
  try {
    const token = await getVercelOidcToken();
    response = await fetch(upstream, {
      headers: { Authorization: `Bearer ${token}`, Accept: "application/json" },
    });
  } catch {
    return json({ error: "skills.sh 호출에 실패했다." }, 502);
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

  if (response.status === 404 && options.notFoundMessage) {
    return json({ error: options.notFoundMessage }, 404, { "Cache-Control": "s-maxage=300" });
  }

  if (PASSTHROUGH_STATUSES.has(response.status)) {
    const headers: Record<string, string> = {};
    const retryAfter = response.headers.get("Retry-After");
    if (retryAfter !== null) headers["Retry-After"] = retryAfter;
    return json({ error: `skills.sh 가 ${response.status} 를 반환했다.` }, response.status, headers);
  }

  return json({ error: `skills.sh 응답 오류 (${response.status})` }, 502);
}

const SEGMENT = /^[A-Za-z0-9_.-]+$/;

/**
 * `id` 쿼리(source/slug, 예: anthropics/skills/frontend-design)를 검사해 경로 조각으로 돌려준다.
 * source 는 GitHub 저장소(owner/repo) 이거나 도메인(open.feishu.cn) 하나다.
 */
export function skillPath(id: string | null): string[] | null {
  if (id === null) return null;
  const parts = id.split("/");
  if (parts.length < 2 || parts.length > 3) return null;
  if (!parts.every((part) => SEGMENT.test(part) && part !== "." && part !== "..")) return null;
  return parts;
}
