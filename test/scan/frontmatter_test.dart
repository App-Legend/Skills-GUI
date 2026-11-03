import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/scan/frontmatter.dart';

void main() {
  test('plain', () {
    final r = parseFrontmatter('---\nname: a\ndescription: b\n---\n# x');
    expect(r.name, 'a');
    expect(r.description, 'b');
  });
  test('foldedDescription', () {
    final r = parseFrontmatter('---\nname: a\ndescription: >\n  one\n  two\n---\n');
    expect(r.description, 'one two');
  });
  test('literalDescription', () {
    final r = parseFrontmatter('---\nname: a\ndescription: |\n  one\n  two\n---\n');
    expect(r.description, 'one\ntwo');
  });
  test('quoted', () {
    final r = parseFrontmatter('---\nname: a\ndescription: "a: b"\n---\n');
    expect(r.description, 'a: b');
  });
  test('missingName', () {
    expect(parseFrontmatter('---\ndescription: b\n---\n').name, isNull);
  });
  test('noFrontmatter', () {
    expect(() => parseFrontmatter('# x'), throwsFormatException);
  });
  test('badYaml', () {
    expect(() => parseFrontmatter('---\nname: [\n---'), throwsFormatException);
  });
  test('crlf', () {
    expect(parseFrontmatter('---\r\nname: a\r\n---\r\n').name, 'a');
  });
}
