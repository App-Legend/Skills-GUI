import { json, proxySkills, skillPath } from "../lib/skills.js";

/**
 * 스킬 하나의 상세와 파일 내용. `id=source/slug` (예: anthropics/skills/frontend-design).
 * 응답: { id, source, slug, installs, hash, files: [{ path, contents }] }
 */
export async function GET(request: Request): Promise<Response> {
  const parts = skillPath(new URL(request.url).searchParams.get("id"));
  if (parts === null) {
    return json({ error: "id는 source/slug 형식이어야 합니다." }, 400);
  }
  const upstream = new URL(`https://skills.sh/api/v1/skills/${parts.map(encodeURIComponent).join("/")}`);
  return proxySkills(upstream, { notFoundMessage: "skills.sh에서 이 스킬을 찾지 못했습니다." });
}
