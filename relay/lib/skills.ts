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
 */
export async function proxySkills(upstream: URL): Promise<Response> {
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
