// Unit tests for entry_edit_sheet.dart's pure date-clamping helper.
//
// clampDateTime is the bounding math behind EntryEditSheet's
// DateEditPicker.free — extracted so it's testable without driving the
// Material date/time picker dialogs (see the `advisor` review that flagged
// the interactive-only coverage as a gap for this exact logic).

import 'package:drinks_mate/src/widgets/entry_edit_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final first = DateTime(2026, 6, 1);
  final last = DateTime(2026, 6, 30);

  test('value inside [first, last] is returned unchanged', () {
    final value = DateTime(2026, 6, 15);
    expect(clampDateTime(value, first, last), value);
  });

  test('value before first is clamped up to first', () {
    final value = DateTime(2026, 5, 1);
    expect(clampDateTime(value, first, last), first);
  });

  test('value after last is clamped down to last', () {
    final value = DateTime(2026, 7, 1);
    expect(clampDateTime(value, first, last), last);
  });

  test('value exactly at first is returned unchanged (inclusive bound)', () {
    expect(clampDateTime(first, first, last), first);
  });

  test('value exactly at last is returned unchanged (inclusive bound)', () {
    expect(clampDateTime(last, first, last), last);
  });
}
