/// Pure-Dart domain model for a user's physical profile.
///
/// All values metric-canonical (C1). Collected during onboarding; used by
/// the hydration-goal suggestion (F2) and BAC estimation (Party Mode).
/// No Drift types — the repository maps [UserProfileRow] → [UserProfile].
class UserProfile {
  const UserProfile({
    required this.id,
    this.username,
    this.gender,
    this.weightKg,
    this.heightCm,
    this.birthDate,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;

  /// Display name — same character rules as data-model.md §Username.
  final String? username;

  /// 'male' | 'female' | 'unspecified'. Stored as-is; displayed localised.
  final String? gender;

  /// Body weight in kilograms.
  final double? weightKg;

  /// Height in centimetres.
  final double? heightCm;

  /// ISO-8601 date string, e.g. "1990-06-15".
  final String? birthDate;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Soft-delete marker; null means the record is live.
  final DateTime? deletedAt;

  UserProfile copyWith({
    String? id,
    Object? username = _sentinel,
    Object? gender = _sentinel,
    Object? weightKg = _sentinel,
    Object? heightCm = _sentinel,
    Object? birthDate = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? deletedAt = _sentinel,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username == _sentinel ? this.username : username as String?,
      gender: gender == _sentinel ? this.gender : gender as String?,
      weightKg: weightKg == _sentinel ? this.weightKg : weightKg as double?,
      heightCm: heightCm == _sentinel ? this.heightCm : heightCm as double?,
      birthDate: birthDate == _sentinel ? this.birthDate : birthDate as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt:
          deletedAt == _sentinel ? this.deletedAt : deletedAt as DateTime?,
    );
  }
}

const _sentinel = Object();
