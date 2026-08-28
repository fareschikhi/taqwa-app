import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Finds layout idioms that only behave correctly under a left-to-right tree.
///
/// The app was written LTR-with-everything-right-aligned; this guard exists so
/// that convention cannot creep back one screen at a time.
List<String> offendingLines(RegExp pattern) {
  final offenders = <String>[];
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));

  for (final file in files) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (pattern.hasMatch(lines[i])) {
        offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
      }
    }
  }
  return offenders;
}

void main() {
  test('no hardcoded TextAlign direction', () {
    expect(offendingLines(RegExp(r'TextAlign\.(left|right)')), isEmpty);
  });

  test('nothing forces the tree left-to-right', () {
    expect(offendingLines(RegExp(r'TextDirection\.ltr')), isEmpty);
  });
}
