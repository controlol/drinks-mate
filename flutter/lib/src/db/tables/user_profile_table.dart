import 'package:drift/drift.dart';

/// Drift table for user profile data — collected during onboarding.
///
/// Schema v3 addition. Used by hydration-goal suggestion (F2) and BAC
/// estimation (Party Mode). All values metric-canonical (C1).
/// No Phase-2 entities (C0). Soft-delete via deletedAt.
///
/// [DataClassName] avoids a name collision with the pure-Dart domain model
/// [UserProfile] in lib/src/models/user_profile.dart.
@DataClassName('UserProfileRow')
class UserProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get gender => text().nullable()();

  /// Stored in kilograms (metric canonical — C1).
  RealColumn get weightKg => real().nullable()();

  /// Stored in centimetres (metric canonical — C1).
  RealColumn get heightCm => real().nullable()();

  /// ISO-8601 date string, e.g. "1990-06-15". Nullable — optional during
  /// onboarding but required for Party Mode BAC + under-18 gate.
  TextColumn get birthDate => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
