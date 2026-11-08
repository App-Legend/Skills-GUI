/// 스킬 카테고리.
///
/// skills.sh 응답에는 카테고리가 없어서 스킬 이름·slug·출처(저장소) 를
/// 단어로 잘라 키워드 표와 맞춰 나눈다. 한 스킬이 여러 카테고리에 들 수 있다.
enum SkillCategory {
  frontend('프론트엔드'),
  backend('백엔드'),
  devops('데브옵스·클라우드'),
  design('디자인'),
  ai('AI·에이전트'),
  data('데이터'),
  testing('테스트·품질'),
  workflow('설계·작업 흐름'),
  docs('문서·글쓰기'),
  media('영상·미디어'),
  productivity('협업·생산성'),
  other('기타');

  const SkillCategory(this.label);

  final String label;
}

/// 표 순서가 대표 카테고리 우선순위다. 좁은 분야를 넓은 분야(AI 등)보다 앞에 둔다.
// dart format off
const Map<SkillCategory, Set<String>> _keywords = {
  SkillCategory.testing: {
    'test', 'tests', 'testing', 'tdd', 'e2e', 'playwright', 'jest', 'vitest',
    'cypress', 'qa', 'review', 'lint', 'debug', 'debugging', 'bug', 'bugs',
    'diagnosing', 'quality', 'guardrails', 'audit', 'security',
  },
  SkillCategory.design: {
    'design', 'designer', 'figma', 'ui', 'ux', 'taste', 'brand', 'branding',
    'canvas', 'icon', 'icons', 'theme', 'typography', 'logo', 'sketch',
  },
  SkillCategory.frontend: {
    'frontend', 'react', 'nextjs', 'next', 'vue', 'nuxt', 'svelte', 'angular',
    'web', 'html', 'css', 'tailwind', 'shadcn', 'expo', 'flutter', 'swiftui',
    'ios', 'android', 'mobile', 'browser', 'composition', 'astro', 'vite',
  },
  SkillCategory.backend: {
    'backend', 'api', 'apis', 'server', 'database', 'db', 'postgres',
    'postgresql', 'mysql', 'sql', 'supabase', 'prisma', 'fastify', 'express',
    'django', 'rails', 'laravel', 'spring', 'node', 'auth', 'graphql',
    'redis', 'firebase', 'stripe', 'payments', 'openapi', 'cloudbase',
    'python',
  },
  SkillCategory.devops: {
    'devops', 'docker', 'kubernetes', 'k8s', 'terraform', 'ci', 'cd',
    'deploy', 'deployment', 'vercel', 'aws', 'azure', 'gcp', 'cloud', 'infra',
    'git', 'github', 'commit', 'merge', 'pre', 'observability', 'monitoring',
    'appinsights', 'quotas', 'migrate', 'migration', 'compute', 'storage',
    'cloudflare', 'netlify',
  },
  SkillCategory.data: {
    'data', 'analytics', 'pandas', 'kusto', 'sheets', 'excel', 'xlsx', 'csv',
    'chart', 'charts', 'dashboard', 'bigquery', 'snowflake', 'etl', 'base',
  },
  SkillCategory.media: {
    'video', 'videos', 'image', 'images', 'audio', 'music', 'animation',
    'animations', 'animate', 'storyboard', 'screenshots', 'photography',
    'choreograph', 'hyperframes', 'remotion', 'media', 'avatar', 'photo',
    'keyframes', 'podcast', 'voice', 'tts',
  },
  SkillCategory.docs: {
    'doc', 'docs', 'documentation', 'readme', 'writing', 'write', 'markdown',
    'pdf', 'docx', 'pptx', 'slides', 'wiki', 'spec', 'note', 'notes', 'teach',
    'beats', 'shape', 'questionnaire', 'blog', 'copywriting',
  },
  SkillCategory.productivity: {
    'lark', 'feishu', 'slack', 'notion', 'calendar', 'mail', 'email', 'task',
    'tasks', 'okr', 'meeting', 'minutes', 'im', 'approval', 'standup',
    'tickets', 'triage', 'handoff', 'attendance', 'contact', 'drive',
    'linear', 'jira', 'workflow', 'twitter', 'reddit', 'automation', 'vc',
    'whiteboard',
  },
  SkillCategory.workflow: {
    'architecture', 'codebase', 'implement', 'prototype', 'brainstorming',
    'plan', 'plans', 'planning', 'executing', 'prd', 'issues', 'refactor',
    'refactoring', 'modeling', 'domain', 'scaffold', 'retro', 'research',
    'explore', 'verification', 'subagent', 'development', 'grill', 'grilling',
    'wizard', 'pr', 'orchestration', 'loop', 'intake', 'modules',
  },
  SkillCategory.ai: {
    'ai', 'llm', 'llms', 'agent', 'agents', 'prompt', 'prompts', 'rag', 'mcp',
    'model', 'models', 'foundry', 'adk', 'openai', 'claude', 'gemini', 'eval',
    'evals', 'aigateway', 'codex', 'copilot',
  },
};
// dart format on

final _splitter = RegExp(r'[^a-z0-9]+');

List<String> _tokens(String text) =>
    text.toLowerCase().split(_splitter).where((t) => t.isNotEmpty).toList();

/// 스킬이 속한 카테고리들. 대표 카테고리가 맨 앞이고, 맞는 게 없으면 [기타] 하나.
///
/// 이름·slug 에서 먼저 찾고, 없을 때만 출처(저장소 이름)로 정한다.
/// 출처는 저장소 전체에 붙은 이름이라 스킬 하나의 분야보다 넓기 때문이다.
List<SkillCategory> categorize({
  required String name,
  required String slug,
  required String source,
}) {
  final fromName = _match({..._tokens(name), ..._tokens(slug)});
  if (fromName.isNotEmpty) return fromName;
  final fromSource = _match(_tokens(source).toSet());
  return fromSource.isNotEmpty ? fromSource : const [SkillCategory.other];
}

List<SkillCategory> _match(Set<String> tokens) => [
  for (final entry in _keywords.entries)
    if (tokens.any(entry.value.contains)) entry.key,
];
