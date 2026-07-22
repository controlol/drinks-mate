/// Age-in-years calculation from a birth date.
///
/// Source: Parity Rulebook → "BAC: Watson TBW" — `age_years = floor((today −
/// birthDate) / 365.25)`. Shared by the Watson TBW model (`ageYears` input)
/// and the Party Mode 18+ gate (settings screen, party-session start).
library;

/// Returns the age in whole years, per the Parity Rulebook day-count formula.
///
/// [today] and [birthDate] should use the same time zone (both local or both
/// UTC) — mixing them would skew the day count by the zone offset.
int ageYearsFromBirthDate({
  required DateTime birthDate,
  required DateTime today,
}) {
  final days = today.difference(birthDate).inDays;
  return (days / 365.25).floor();
}
