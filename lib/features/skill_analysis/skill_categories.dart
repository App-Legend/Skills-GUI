/// 스킬 카테고리. 목록은 claudeskills.info/ko/skills 의 카테고리를 옮겼다(2026-11-08 기준).
/// relay/api/skill-analysis.ts 의 CATEGORY_SLUGS와 같은 순서·값을 유지한다.
class SkillCategory {
  const SkillCategory(this.slug, this.label);
  final String slug;
  final String label;
}

const skillCategories = [
  SkillCategory('devops', 'DevOps'),
  SkillCategory('security', '보안'),
  SkillCategory('frontend', '프론트엔드'),
  SkillCategory('workflow', '워크플로'),
  SkillCategory('testing', '테스트'),
  SkillCategory('documentation', '문서'),
  SkillCategory('coding', '코딩'),
  SkillCategory('backend', '백엔드'),
  SkillCategory('integrations', '연동'),
  SkillCategory('marketing', '마케팅'),
  SkillCategory('research', '연구'),
  SkillCategory('finance', '금융'),
  SkillCategory('productivity', '생산성'),
  SkillCategory('database', '데이터베이스'),
  SkillCategory('debugging', '디버깅'),
  SkillCategory('code-quality', '코드 품질'),
  SkillCategory('mobile', '모바일 개발'),
  SkillCategory('communication', '커뮤니케이션'),
  SkillCategory('ai-engineering', 'AI 엔지니어링'),
  SkillCategory('data-science', '데이터 과학'),
  SkillCategory('social-media', '소셜 미디어'),
  SkillCategory('ui-ux', 'UI/UX'),
  SkillCategory('video', '비디오'),
  SkillCategory('writing', '글쓰기'),
  SkillCategory('product-management', '제품 관리'),
  SkillCategory('image', '이미지'),
  SkillCategory('skill-development', '스킬 개발'),
  SkillCategory('search', '검색'),
  SkillCategory('git', 'Git'),
  SkillCategory('media', '미디어 및 그래픽'),
  SkillCategory('agent-ops', '에이전트 운영'),
  SkillCategory('game-development', '게임 개발'),
  SkillCategory('seo', 'SEO'),
  SkillCategory('automation', '자동화'),
  SkillCategory('sales', '영업'),
  SkillCategory('presentation', '프레젠테이션'),
  SkillCategory('ecommerce', '이커머스'),
  SkillCategory('python', 'Python'),
  SkillCategory('release-management', '릴리스 관리'),
  SkillCategory('web3', 'Web3'),
  SkillCategory('business-operations', '비즈니스 운영'),
  SkillCategory('legal', '법률'),
  SkillCategory('java-jvm', 'Java / JVM'),
  SkillCategory('healthcare', '헬스케어'),
  SkillCategory('diagrams', '다이어그램'),
  SkillCategory('typescript', 'TypeScript'),
  SkillCategory('human-resources', '인사'),
  SkillCategory('rust', 'Rust'),
  SkillCategory('pdf', 'PDF'),
  SkillCategory('education', '교육'),
  SkillCategory('persona', '페르소나'),
  SkillCategory('accounting', '회계'),
  SkillCategory('php', 'PHP'),
  SkillCategory('resume', '이력서'),
  SkillCategory('customer-support', '고객 지원'),
  SkillCategory('dotnet', '.NET'),
  SkillCategory('maps', '지도'),
  SkillCategory('cpp', 'C++'),
  SkillCategory('ruby', 'Ruby'),
  SkillCategory('travel', '여행'),
  SkillCategory('real-estate', '부동산'),
];

final Map<String, SkillCategory> _bySlug = {
  for (final c in skillCategories) c.slug: c,
};

SkillCategory? categoryOf(String slug) => _bySlug[slug];

String categoryLabel(String slug) => _bySlug[slug]?.label ?? slug;
