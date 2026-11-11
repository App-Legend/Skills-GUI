import { json, proxySkills, skillPath } from "../lib/skills.js";

/**
 * 스킬 보안 점검 결과. `id=source/slug`.
 * 응답: { id, source, slug, audits: [{ provider, slug, status, summary, auditedAt, riskLevel? }] }
 * 아직 점검 기록이 없으면 404.
 */
export async function GET(request: Request): Promise<Response> {
  const parts = skillPath(new URL(request.url).searchParams.get("id"));
  if (parts === null) {
    return json({ error: "id는 source/slug 형식이어야 합니다." }, 400);
  }
  const upstream = new URL(`https://skills.sh/api/v1/skills/audit/${parts.map(encodeURIComponent).join("/")}`);
  return proxySkills(upstream, { notFoundMessage: "아직 보안 점검 기록이 없다." });
}
