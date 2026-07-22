// Unit tests for entry_edit_sheet.dart's pure date-clamping helper, plus
// widget tests for its DraggableScrollableSheet sizing (issue #100).
//
// clampDateTime is the bounding math behind EntryEditSheet's
// DateEditPicker.free — extracted so it's testable without driving the
// Material date/time picker dialogs (see the `advisor` review that flagged
// the interactive-only coverage as a gap for this exact logic).

import 'package:drinks_mate/src/models/beverage_type.dart';
import 'package:drinks_mate/src/models/drink_entry.dart';
import 'package:drinks_mate/src/widgets/entry_edit_sheet.dart';
import 'package:flutter/material.dart';
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

  // ---------------------------------------------------------------------
  // Sheet-height widget tests (issue #100).
  //
  // Source: design/user-experience.md §S3/§S6/§S9 — "The edit sheet opens
  // already expanded to near-full height, not a short partial sheet the
  // user has to drag open — every editable field is visible immediately
  // without an extra gesture."
  //
  // Prior coverage (history_day_screen_test.dart,
  // party_session_log_screen_test.dart, today_drinks_screen_test.dart) only
  // ever exercised field pre-fill/save behaviour after `pumpAndSettle()`;
  // none of it distinguished a sheet that opens already at near-full height
  // from one that opens small and is merely *scrollable* internally (a
  // partial-height DraggableScrollableSheet still has a working
  // SingleChildScrollView bound to its own controller, so "can reach Save
  // by scrolling" passes either way and doesn't catch a regression back to
  // a short initial size). The height itself is what the spec requires, so
  // that's what these tests pin.
  // ---------------------------------------------------------------------

  final entry = DrinkEntry(
    id: 'e1',
    beverageType: BeverageType.beer,
    volumeMl: 330,
    abvPercent: 5.0,
    consumedAt: DateTime.utc(2026, 6, 22, 20, 0),
    createdAt: DateTime.utc(2026, 6, 22, 20, 0),
    updatedAt: DateTime.utc(2026, 6, 22, 20, 0),
  );

  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => EntryEditSheet(
                  entry: entry,
                  onSave: ({
                    required volumeMl,
                    name,
                    abvPercent,
                    required priceMinor,
                    required currency,
                    required consumedAt,
                  }) async {},
                  datePicker: const DateEditPicker.dayLocked(boundaryHour: 4),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    // Deliberately no tester.drag() on the sheet — the whole point under
    // test is that the sheet needs none to reach its expanded height.
    await tester.pumpAndSettle();
  }

  testWidgets(
    'the edit sheet opens already at its max height (initialChildSize == '
    'maxChildSize) — the "no extra drag gesture" invariant from the spec; '
    'a sheet that instead opens short (e.g. copying log_drink_sheet\'s '
    '0.6 initial) would require the user to drag it up first',
    (tester) async {
      await pumpSheet(tester);

      final sheet = tester.widget<DraggableScrollableSheet>(
        find.byType(DraggableScrollableSheet),
      );
      expect(
        sheet.initialChildSize,
        sheet.maxChildSize,
        reason: 'opening below maxChildSize means the sheet starts as a short '
            'partial sheet, contradicting "opens already expanded to '
            'near-full height ... without an extra gesture".',
      );
    },
  );

  testWidgets(
    'the edit sheet\'s max height is near-full (>= 0.9 of the modal '
    'route\'s available height) — the "near-full height" half of the spec '
    'sentence, distinct from the "no drag needed" half above',
    (tester) async {
      await pumpSheet(tester);

      final sheet = tester.widget<DraggableScrollableSheet>(
        find.byType(DraggableScrollableSheet),
      );
      expect(sheet.maxChildSize, greaterThanOrEqualTo(0.9));
    },
  );
}
