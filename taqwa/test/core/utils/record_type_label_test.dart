import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/utils/record_type_label.dart';

void main() {
  test('names new memorization in full', () {
    expect(recordTypeLabel({'memorizationType': 'MEMORIZING'}), 'حفظ جديد');
  });

  test('names a revision by its type', () {
    expect(recordTypeLabel({'memorizationType': 'SMALLREVISION'}), 'جمع');
  });

  test('marks a repeat in brackets', () {
    expect(
      recordTypeLabel({'memorizationType': 'MEMORIZING', 'isRepeat': true}),
      'حفظ جديد (اعادة)',
    );
    expect(
      recordTypeLabel({'memorizationType': 'BIGREVISION', 'isRepeat': true}),
      'مراجعة وضبط (اعادة)',
    );
  });

  // Older rows and older servers send no flag at all.
  test('treats a missing flag or type as a plain new memorization', () {
    expect(recordTypeLabel({}), 'حفظ جديد');
  });

  // برنامج التسميع rows sit in the same lists as Quran rows, so their type
  // line says which program they belong to.
  test('names a tasmee entry before its type', () {
    expect(
      recordTypeLabel({'subject': 'TASMEE', 'memorizationType': 'BIGREVISION'}),
      'تسميع · مراجعة وضبط',
    );
    expect(
      recordTypeLabel({
        'subject': 'TASMEE',
        'memorizationType': 'MEMORIZING',
        'isRepeat': true,
      }),
      'تسميع · حفظ جديد (اعادة)',
    );
  });

  group('recordMistakes', () {
    test('reads a tasmee entry\'s notes, trimmed', () {
      expect(
        recordMistakes({'subject': 'TASMEE', 'mistakes': ' تردد في الآية 3 '}),
        'تردد في الآية 3',
      );
    });

    test('is null when there are none, or on any other subject', () {
      expect(recordMistakes({'subject': 'TASMEE'}), isNull);
      expect(recordMistakes({'subject': 'TASMEE', 'mistakes': '  '}), isNull);
      expect(recordMistakes({'subject': 'QURAN', 'mistakes': 'x'}), isNull);
    });
  });
}
