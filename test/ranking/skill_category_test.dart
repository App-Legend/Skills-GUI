import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/features/ranking/category/skill_category.dart';

List<SkillCategory> _of(String name, [String source = 'someone/skills']) =>
    categorize(name: name, slug: name, source: source);

void main() {
  test('이름의 단어로 분야를 고른다', () {
    expect(_of('vercel-react-best-practices').first, SkillCategory.frontend);
    expect(
      _of('supabase-postgres-best-practices').first,
      SkillCategory.backend,
    );
    expect(_of('azure-deploy').first, SkillCategory.devops);
    expect(_of('frontend-design').first, SkillCategory.design);
    expect(_of('tdd').first, SkillCategory.testing);
    expect(_of('improve-codebase-architecture').first, SkillCategory.workflow);
    expect(_of('ai-video-generation').first, SkillCategory.media);
    expect(_of('lark-calendar').first, SkillCategory.productivity);
    expect(_of('writing-for-agents').first, SkillCategory.docs);
  });

  test('한 스킬이 여러 분야에 들 수 있습니다', () {
    final categories = _of('ai-video-generation');
    expect(categories, contains(SkillCategory.media));
    expect(categories, contains(SkillCategory.ai));
  });

  test('이름으로 못 정하면 저장소 이름으로 정합니다', () {
    expect(_of('helper', 'heygen-com/hyperframes'), [SkillCategory.media]);
  });

  test('이름에서 찾으면 저장소 이름은 보지 않습니다', () {
    expect(_of('react-tips', 'heygen-com/hyperframes'), [
      SkillCategory.frontend,
    ]);
  });

  test('어디에도 안 맞으면 기타 하나', () {
    expect(_of('caveman', 'juliusbrussee/caveman'), [SkillCategory.other]);
  });

  test('단어 일부만 같은 것은 맞추지 않습니다', () {
    // "reactive" 는 "react" 가 아니다.
    expect(_of('reactive-zzz').contains(SkillCategory.frontend), isFalse);
  });

  test('대소문자와 구분 기호를 가리지 않습니다', () {
    expect(_of('React_Native.Tips').first, SkillCategory.frontend);
  });
}
