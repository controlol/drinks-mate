import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../models/beverage_type.dart';
import '../models/drink_entry.dart';
import '../models/drink_preset.dart';
import '../models/meal.dart';
import '../models/party_session.dart';
import '../models/party_session_price.dart';

/// Repository seam — the only way widgets/services touch persisted Party
/// Session data (D2). Converts Drift row types ([PartySessionRow],
/// [PartySessionPriceRow], [MealRow], [DrinkEntryRow]) to pure-Dart domain
/// models before returning. Drift types never escape this class.
///
/// The BAC estimate itself is computed by the pure-Dart `core` package
/// (`bac.dart`, C4) — this repository only supplies the raw session/entry
/// data and the orphan-absorption decision, which needs the same BAC-decay
/// formula to know whether an orphan drink is still "active".
class PartySessionRepository {
  PartySessionRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// party-session.md §Ending a session: "12 hours after the most recently
  /// logged alcoholic drink ... (or 12 hours after startedAt if none)."
  static const Duration _autoEndAfter = Duration(hours: 12);

  // ---------------------------------------------------------------------------
  // Session lifecycle
  // ---------------------------------------------------------------------------

  /// Reactive stream of the current open session (`endedAt IS NULL`), or null.
  Stream<PartySession?> watchActiveSession() => _db.watchActiveSession().map(
        (row) => row == null ? null : _rowToSession(row),
      );

  /// One-shot read of session [id] — lets callers refresh a [PartySession]
  /// snapshot after mutating it (e.g. the pricing prompt's writes to
  /// `useSessionPrices`/token config right after [startSession]), so a
  /// stale in-memory copy is never used for [resolvePrice].
  ///
  /// Throws [StateError] if [id] does not exist.
  Future<PartySession> getSessionById(String id) async {
    final row = await _db.getPartySessionById(id);
    if (row == null) throw StateError('PartySession $id not found.');
    return _rowToSession(row);
  }

  /// Starts a new session, enforcing at-most-one-active-session.
  ///
  /// Applies the lazy 12h auto-end rule to any existing active session
  /// first (party-session.md §Auto-end is computed lazily); if a session is
  /// *still* active afterwards, throws [StateError] — single-active-session
  /// enforcement (data-model.md §PartySession: "at most one active session
  /// ... at any time").
  ///
  /// [startedAt] defaults to [now] (both UTC). Passing an earlier value lets
  /// callers start a session "at the drink's consumedAt time"
  /// (party-session.md §Logging alcohol when no session is active).
  ///
  /// Immediately runs orphan absorption against the new session (no opt-out
  /// — party-session.md §Absorbing orphan drinks: "The user cannot uncheck
  /// individual drinks").
  ///
  /// Throws [ArgumentError] if [tokenValueMinor] is set without
  /// [tokenValueCurrency], or if [tokenName] fails [validateUsername]
  /// (1–30 chars, same whitelist as username — Parity Rulebook §Username
  /// length).
  Future<PartySession> startSession({
    DateTime? startedAt,
    bool useSessionPrices = false,
    String? tokenName,
    int? tokenValueMinor,
    String? tokenValueCurrency,
    DateTime? now,
  }) async {
    if (tokenValueMinor != null && tokenValueCurrency == null) {
      throw ArgumentError(
        'tokenValueCurrency is required when tokenValueMinor is set',
      );
    }
    var normalizedTokenName = tokenName;
    if (tokenName != null) {
      // NFC-normalise before validating/storing, same rule as username and
      // preset name — visually identical inputs must produce the same stored
      // bytes (Parity Rulebook §Username normalisation).
      normalizedTokenName = normalizeNfc(tokenName);
      final validation = validateUsername(normalizedTokenName, minLength: 1);
      if (!validation.isValid) {
        throw ArgumentError.value(tokenName, 'tokenName', validation.error);
      }
    }

    final nowUtc = (now ?? DateTime.now()).toUtc();
    final startedAtUtc = (startedAt ?? nowUtc).toUtc();

    await checkAndApplyAutoEnd(now: nowUtc);

    final stillActive = await _db.getActiveSession();
    if (stillActive != null) {
      throw StateError(
        'A party session is already active (${stillActive.id}).',
      );
    }

    final id = _uuid.v4();
    // Insert + absorption run in one transaction so a failure partway through
    // (e.g. orphanAbsorption's missing-profile precondition) can never leave
    // a dangling active session behind.
    await _db.transaction(() async {
      await _db.insertPartySession(
        PartySessionsCompanion.insert(
          id: id,
          startedAt: startedAtUtc,
          useSessionPrices: useSessionPrices,
          tokenName: Value(normalizedTokenName),
          tokenValueMinor: Value(tokenValueMinor),
          tokenValueCurrency: Value(tokenValueCurrency),
          createdAt: nowUtc,
          updatedAt: nowUtc,
        ),
      );

      await orphanAbsorption(
        newSessionId: id,
        startedAt: startedAtUtc,
        now: nowUtc,
      );
    });

    final row = await _db.getPartySessionById(id);
    return _rowToSession(row!);
  }

  /// Ends session [id]. [reason] is `manual` for a user-initiated end;
  /// [checkAndApplyAutoEnd] handles the `auto_timeout` path internally.
  ///
  /// Throws [StateError] if [id] does not exist.
  Future<void> endSession(
    String id,
    PartySessionEndReason reason, {
    DateTime? now,
  }) async {
    final nowUtc = (now ?? DateTime.now()).toUtc();
    final rows = await _db.updatePartySessionFields(
      id,
      PartySessionsCompanion(
        endedAt: Value(nowUtc),
        endReason: Value(reason.stored),
        updatedAt: Value(nowUtc),
      ),
    );
    if (rows == 0) throw StateError('PartySession $id not found.');
  }

  /// Applies the lazy 12h auto-end rule to the currently active session, if
  /// any. A no-op if there is no active session or it has not reached its
  /// auto-end mark yet.
  ///
  /// Spec trigger points (party-session.md §Auto-end is computed lazily):
  /// app foreground, Today/Party/History tab open, drink logged, settings
  /// opened. [startSession] always calls this first; callers implementing
  /// those other trigger points should call it too.
  ///
  /// `endedAt` is set to the correct 12h mark, **not** to [now] — data-model.md
  /// §PartySession → Auto-end semantics.
  Future<void> checkAndApplyAutoEnd({DateTime? now}) async {
    final nowUtc = (now ?? DateTime.now()).toUtc();
    final active = await _db.getActiveSession();
    if (active == null) return;

    final autoEndAt = await _autoEndMark(active);
    if (!nowUtc.isBefore(autoEndAt)) {
      await _db.updatePartySessionFields(
        active.id,
        PartySessionsCompanion(
          endedAt: Value(autoEndAt),
          endReason: Value(PartySessionEndReason.autoTimeout.stored),
          updatedAt: Value(nowUtc),
        ),
      );
    }
  }

  Future<DateTime> _autoEndMark(PartySessionRow session) async {
    final last = await _db.getLastAlcoholicEntryInSession(
      session.id,
      _alcoholicTypeStrings,
    );
    final base = last?.consumedAt ?? session.startedAt;
    return base.add(_autoEndAfter);
  }

  // ---------------------------------------------------------------------------
  // Meals
  // ---------------------------------------------------------------------------

  /// Logs a meal for [sessionId]. [eatenAt] defaults to [now].
  Future<Meal> addMeal({
    required String sessionId,
    required MealSize size,
    DateTime? eatenAt,
    DateTime? now,
  }) async {
    final nowUtc = (now ?? DateTime.now()).toUtc();
    final eatenAtUtc = (eatenAt ?? nowUtc).toUtc();
    final id = _uuid.v4();
    await _db.insertMeal(
      MealsCompanion.insert(
        id: id,
        partySessionId: sessionId,
        size: size.stored,
        eatenAt: eatenAtUtc,
        createdAt: nowUtc,
        updatedAt: nowUtc,
      ),
    );
    return Meal(
      id: id,
      partySessionId: sessionId,
      size: size,
      eatenAt: eatenAtUtc,
      createdAt: nowUtc,
      updatedAt: nowUtc,
    );
  }

  /// Reactive stream of live meals for [sessionId], oldest first.
  Stream<List<Meal>> watchSessionMeals(String sessionId) => _db
      .watchSessionMeals(sessionId)
      .map((rows) => rows.map(_rowToMeal).toList());

  // ---------------------------------------------------------------------------
  // Drink entries
  // ---------------------------------------------------------------------------

  /// Logs an alcoholic drink into [sessionId], snapshotting preset values at
  /// the current time (log immutability — data-model.md §Snapshot semantics).
  ///
  /// [preset.beverageType] must be alcoholic (party-session.md: alcoholic
  /// types are "only logged during an active Party Session").
  ///
  /// Money and tokens are mutually exclusive per drink (data-model.md
  /// §DrinkEntry): pass at most one of ([priceMinor] + [currency]) or
  /// ([priceTokens] + optionally [tokenValueMinor] + [tokenValueCurrency]).
  /// Throws [ArgumentError] on a mutually-exclusive or incomplete pricing
  /// combination, or if [preset.beverageType] is not alcoholic.
  Future<DrinkEntry> logAlcoholicDrink({
    required DrinkPreset preset,
    required String sessionId,
    int? volumeMl,
    double? abvPercent,
    DateTime? consumedAt,
    int? priceMinor,
    String? currency,
    int? priceTokens,
    int? tokenValueMinor,
    String? tokenValueCurrency,
    DateTime? now,
  }) async {
    if (!preset.beverageType.isAlcoholic) {
      throw ArgumentError.value(
        preset.beverageType,
        'preset.beverageType',
        'Must be alcoholic to log into a Party Session',
      );
    }
    if (priceMinor != null && priceTokens != null) {
      throw ArgumentError(
        'priceMinor and priceTokens are mutually exclusive per drink',
      );
    }
    if ((priceMinor == null) != (currency == null)) {
      throw ArgumentError(
        'currency is required when priceMinor is set, and must be null '
        'otherwise',
      );
    }
    if (priceTokens == null && tokenValueMinor != null) {
      throw ArgumentError('tokenValueMinor requires priceTokens to be set');
    }
    if ((tokenValueMinor == null) != (tokenValueCurrency == null)) {
      throw ArgumentError(
        'tokenValueCurrency is required when tokenValueMinor is set, and '
        'must be null otherwise',
      );
    }

    final nowUtc = (now ?? DateTime.now()).toUtc();
    final consumedAtUtc = (consumedAt ?? nowUtc).toUtc();
    final id = _uuid.v4();
    final resolvedAbv = abvPercent ?? preset.abvPercent;
    await _db.insertDrinkEntry(
      DrinkEntriesCompanion.insert(
        id: id,
        name: Value(preset.name),
        beverageType: preset.beverageType.stored,
        volumeMl: volumeMl ?? preset.volumeMl,
        abvPercent: Value(resolvedAbv),
        priceMinor: Value(priceMinor),
        currency: Value(currency),
        priceTokens: Value(priceTokens),
        tokenValueMinor: Value(tokenValueMinor),
        tokenValueCurrency: Value(tokenValueCurrency),
        iconKey: Value(preset.iconKey),
        iconColor: Value(preset.iconColor),
        partySessionId: Value(sessionId),
        consumedAt: consumedAtUtc,
        createdAt: nowUtc,
        updatedAt: nowUtc,
      ),
    );
    return DrinkEntry(
      id: id,
      name: preset.name,
      beverageType: preset.beverageType,
      volumeMl: volumeMl ?? preset.volumeMl,
      abvPercent: resolvedAbv,
      priceMinor: priceMinor,
      currency: currency,
      priceTokens: priceTokens,
      tokenValueMinor: tokenValueMinor,
      tokenValueCurrency: tokenValueCurrency,
      iconKey: preset.iconKey,
      iconColor: preset.iconColor,
      partySessionId: sessionId,
      consumedAt: consumedAtUtc,
      createdAt: nowUtc,
      updatedAt: nowUtc,
    );
  }

  /// Reactive stream of live entries belonging to [sessionId], oldest first.
  Stream<List<DrinkEntry>> watchSessionEntries(String sessionId) => _db
      .watchSessionEntries(sessionId)
      .map((rows) => rows.map(_rowToEntry).toList());

  /// Absorbs pre-existing orphan alcoholic drinks (`partySessionId IS NULL`)
  /// into [newSessionId] whose alcohol is still pharmacokinetically active
  /// at [startedAt] (party-session.md §Absorbing orphan drinks when a later
  /// session starts; Parity Rulebook → "Orphan absorption").
  ///
  /// Per orphan: `t_zero = consumedAt + BAC_initial / β`; absorbed iff
  /// `t_zero > startedAt`, else the orphan stays decayed. `BAC_initial` uses
  /// the live [UserProfile] (Watson TBW if height is set, else Widmark
  /// fallback) — no meal modifier, since absorption is a yes/no decision on
  /// residual BAC, not a value read at a point in time.
  ///
  /// Requires a [UserProfile] with `birthDate` set — Party Mode's own
  /// precondition (party-session.md §Required user inputs). Throws
  /// [StateError] if the profile or its birthDate is missing; the UI layer
  /// (issue #22) is responsible for gating session start on profile
  /// completeness before calling [startSession].
  ///
  /// Returns the number of orphans absorbed.
  Future<int> orphanAbsorption({
    required String newSessionId,
    required DateTime startedAt,
    DateTime? now,
  }) async {
    final orphans = await _db.getOrphanAlcoholicEntries(_alcoholicTypeStrings);
    if (orphans.isEmpty) return 0;

    final profile = await _db.getProfile();
    if (profile == null || profile.birthDate == null) {
      throw StateError(
        'UserProfile with birthDate is required for orphan absorption.',
      );
    }

    final nowUtc = (now ?? DateTime.now()).toUtc();
    final startedAtUtc = startedAt.toUtc();
    final gender = _genderFromProfile(profile.gender);
    final weightKg = profile.weightKg ?? 70.0;
    final birthDate = DateTime.parse(profile.birthDate!);

    var absorbedCount = 0;
    for (final orphan in orphans) {
      final consumedAtLocal = orphan.consumedAt.toLocal();
      final ageYears = ageYearsFromBirthDate(
        birthDate: birthDate,
        today: consumedAtLocal,
      );
      final grams = alcoholGrams(
        volumeMl: orphan.volumeMl.toDouble(),
        abvPercent: orphan.abvPercent ?? 0,
      );
      final double bacInitial;
      if (profile.heightCm != null) {
        final tbw = watsonTbwLitres(
          gender: gender,
          ageYears: ageYears,
          heightCm: profile.heightCm!,
          weightKg: weightKg,
        );
        bacInitial = bacInitialWatson(alcoholGrams: grams, tbwLitres: tbw);
      } else {
        bacInitial = bacInitialWidmark(
          alcoholGrams: grams,
          weightKg: weightKg,
          r: widmarkR(gender),
        );
      }

      final tZero = orphan.consumedAt.add(
        Duration(
          microseconds:
              (hoursToZero(bacInitial) * Duration.microsecondsPerHour).round(),
        ),
      );

      if (tZero.isAfter(startedAtUtc)) {
        await _db.absorbOrphanEntry(orphan.id, newSessionId, nowUtc);
        absorbedCount++;
      }
    }
    return absorbedCount;
  }

  // ---------------------------------------------------------------------------
  // Session prices
  // ---------------------------------------------------------------------------

  /// Bulk upsert of per-session price overrides. Each [prices] entry sets or
  /// replaces the live override for its `drinkPresetId` within [sessionId]
  /// (at most one live row per pair — data-model.md §PartySessionPrice).
  ///
  /// Each override's `priceMinor` and `priceTokens` are mutually exclusive;
  /// throws [ArgumentError] otherwise, or if `priceMinor` is set without a
  /// `currency`.
  Future<void> setSessionPrices({
    required String sessionId,
    required List<PartySessionPriceInput> prices,
    DateTime? now,
  }) async {
    for (final p in prices) {
      if (p.priceMinor != null && p.priceTokens != null) {
        throw ArgumentError(
          'priceMinor and priceTokens are mutually exclusive '
          '(drinkPresetId: ${p.drinkPresetId})',
        );
      }
      if ((p.priceMinor == null) != (p.currency == null)) {
        throw ArgumentError(
          'currency is required when priceMinor is set, and must be null '
          'otherwise (drinkPresetId: ${p.drinkPresetId})',
        );
      }
    }

    final nowUtc = (now ?? DateTime.now()).toUtc();
    await _db.transaction(() async {
      final existing = await _db.getSessionPrices(sessionId);
      final existingByPreset = {for (final r in existing) r.drinkPresetId: r};

      for (final p in prices) {
        final existingRow = existingByPreset[p.drinkPresetId];
        if (existingRow != null) {
          await _db.updateSessionPriceById(
            existingRow.id,
            PartySessionPricesCompanion(
              priceMinor: Value(p.priceMinor),
              currency: Value(p.currency),
              priceTokens: Value(p.priceTokens),
              updatedAt: Value(nowUtc),
            ),
          );
        } else {
          await _db.insertSessionPrice(
            PartySessionPricesCompanion.insert(
              id: _uuid.v4(),
              partySessionId: sessionId,
              drinkPresetId: p.drinkPresetId,
              priceMinor: Value(p.priceMinor),
              currency: Value(p.currency),
              priceTokens: Value(p.priceTokens),
              createdAt: nowUtc,
              updatedAt: nowUtc,
            ),
          );
        }
      }
    });
  }

  /// Live price overrides for [sessionId].
  Future<List<PartySessionPrice>> getSessionPrices(String sessionId) async {
    final rows = await _db.getSessionPrices(sessionId);
    return rows.map(_rowToPrice).toList();
  }

  /// Reactive stream of [getSessionPrices] — feeds the session-prices
  /// control's "off — using regular prices" label and the "Manage prices"
  /// sheet (party-session.md §Party tab during a session).
  Stream<List<PartySessionPrice>> watchSessionPrices(String sessionId) => _db
      .watchSessionPrices(sessionId)
      .map((rows) => rows.map(_rowToPrice).toList());

  /// Toggles [PartySession.useSessionPrices] live, mid-session
  /// (party-session.md §Toggle: use session prices). Purely a flag flip —
  /// existing [PartySessionPrice] overrides and already-logged entries are
  /// never touched.
  ///
  /// Throws [StateError] if [sessionId] does not exist.
  Future<void> setUseSessionPrices(
    String sessionId,
    bool value, {
    DateTime? now,
  }) async {
    final nowUtc = (now ?? DateTime.now()).toUtc();
    final rows = await _db.updatePartySessionFields(
      sessionId,
      PartySessionsCompanion(
        useSessionPrices: Value(value),
        updatedAt: Value(nowUtc),
      ),
    );
    if (rows == 0) throw StateError('PartySession $sessionId not found.');
  }

  /// Updates the token configuration on an existing session — usable at
  /// session start (the pricing prompt) or "any time during the session"
  /// (party-session.md §Money vs tokens). Pass `null` for a field to clear
  /// it (e.g. turning tokens off).
  ///
  /// Throws [ArgumentError] if [tokenValueMinor] is set without
  /// [tokenValueCurrency] (or vice versa), or if [tokenName] fails
  /// [validateUsername]. Throws [StateError] if [sessionId] does not exist.
  Future<void> updateTokenConfig({
    required String sessionId,
    String? tokenName,
    int? tokenValueMinor,
    String? tokenValueCurrency,
    DateTime? now,
  }) async {
    if ((tokenValueMinor == null) != (tokenValueCurrency == null)) {
      throw ArgumentError(
        'tokenValueCurrency is required when tokenValueMinor is set, and '
        'must be null otherwise',
      );
    }
    var normalizedTokenName = tokenName;
    if (tokenName != null) {
      normalizedTokenName = normalizeNfc(tokenName);
      final validation = validateUsername(normalizedTokenName, minLength: 1);
      if (!validation.isValid) {
        throw ArgumentError.value(tokenName, 'tokenName', validation.error);
      }
    }

    final nowUtc = (now ?? DateTime.now()).toUtc();
    final rows = await _db.updatePartySessionFields(
      sessionId,
      PartySessionsCompanion(
        tokenName: Value(normalizedTokenName),
        tokenValueMinor: Value(tokenValueMinor),
        tokenValueCurrency: Value(tokenValueCurrency),
        updatedAt: Value(nowUtc),
      ),
    );
    if (rows == 0) throw StateError('PartySession $sessionId not found.');
  }

  /// The most recently *ended* session's pricing config, for the "copy
  /// prices from your last session?" shortcut (party-session.md §Starting a
  /// session — pricing prompt). Returns null when there is no ended session,
  /// or the most recent one has no overrides and no token config to copy.
  Future<LastSessionPricing?> getLastSessionPricing() async {
    final last = await _db.getMostRecentEndedSession();
    if (last == null) return null;
    final prices = await getSessionPrices(last.id);
    if (prices.isEmpty && last.tokenName == null) return null;
    return LastSessionPricing(
      prices: prices,
      tokenName: last.tokenName,
      tokenValueMinor: last.tokenValueMinor,
      tokenValueCurrency: last.tokenValueCurrency,
    );
  }

  /// Resolves the price to snapshot onto a [DrinkEntry] for [preset] within
  /// [session], applying both pricing rules in one place so callers never
  /// duplicate this logic:
  ///
  /// - `useSessionPrices == false`: always the preset's regular price —
  ///   overrides are ignored even though they still exist (party-session.md
  ///   §Toggle: use session prices — "Off: drinks log at their regular price
  ///   even though overrides exist").
  /// - `useSessionPrices == true`: the matching [PartySessionPrice] if one
  ///   exists (and actually sets a price/token value), else the preset's
  ///   regular price (data-model.md §PartySessionPrice → Snapshot at log
  ///   time).
  Future<ResolvedDrinkPrice> resolvePrice({
    required PartySession session,
    required DrinkPreset preset,
  }) async {
    if (session.useSessionPrices) {
      final prices = await getSessionPrices(session.id);
      PartySessionPrice? override;
      for (final p in prices) {
        if (p.drinkPresetId == preset.id) {
          override = p;
          break;
        }
      }
      if (override != null &&
          (override.priceMinor != null || override.priceTokens != null)) {
        if (override.priceTokens != null) {
          return ResolvedDrinkPrice(
            priceTokens: override.priceTokens,
            tokenValueMinor: session.tokenValueMinor,
            tokenValueCurrency: session.tokenValueCurrency,
          );
        }
        return ResolvedDrinkPrice(
          priceMinor: override.priceMinor,
          currency: override.currency,
        );
      }
    }
    return ResolvedDrinkPrice(
      priceMinor: preset.regularPriceMinor,
      currency: preset.regularCurrency,
    );
  }

  // ---------------------------------------------------------------------------
  // Mapping helpers
  // ---------------------------------------------------------------------------

  List<String> get _alcoholicTypeStrings => BeverageType.values
      .where((t) => t.isAlcoholic)
      .map((t) => t.stored)
      .toList();

  static Gender _genderFromProfile(String? gender) => switch (gender) {
        'male' => Gender.male,
        'female' => Gender.female,
        _ => Gender.unspecified,
      };

  static PartySession _rowToSession(PartySessionRow row) => PartySession(
        id: row.id,
        startedAt: row.startedAt,
        endedAt: row.endedAt,
        endReason: row.endReason == null
            ? null
            : PartySessionEndReason.fromStored(row.endReason!),
        useSessionPrices: row.useSessionPrices,
        tokenName: row.tokenName,
        tokenValueMinor: row.tokenValueMinor,
        tokenValueCurrency: row.tokenValueCurrency,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        deletedAt: row.deletedAt,
      );

  static Meal _rowToMeal(MealRow row) => Meal(
        id: row.id,
        partySessionId: row.partySessionId,
        size: MealSizeStorage.fromStored(row.size),
        eatenAt: row.eatenAt,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        deletedAt: row.deletedAt,
      );

  static PartySessionPrice _rowToPrice(PartySessionPriceRow row) =>
      PartySessionPrice(
        id: row.id,
        partySessionId: row.partySessionId,
        drinkPresetId: row.drinkPresetId,
        priceMinor: row.priceMinor,
        currency: row.currency,
        priceTokens: row.priceTokens,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        deletedAt: row.deletedAt,
      );

  static DrinkEntry _rowToEntry(DrinkEntryRow row) => DrinkEntry(
        id: row.id,
        name: row.name,
        beverageType: BeverageType.fromStored(row.beverageType),
        volumeMl: row.volumeMl,
        abvPercent: row.abvPercent,
        priceMinor: row.priceMinor,
        currency: row.currency,
        priceTokens: row.priceTokens,
        tokenValueMinor: row.tokenValueMinor,
        tokenValueCurrency: row.tokenValueCurrency,
        iconKey: row.iconKey,
        iconColor: row.iconColor,
        partySessionId: row.partySessionId,
        consumedAt: row.consumedAt,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        deletedAt: row.deletedAt,
      );
}

/// Input for a single [PartySessionRepository.setSessionPrices] override.
///
/// Exactly one of ([priceMinor] + [currency]) or [priceTokens] should be set;
/// leaving both null means "no override — fall back to the regular price"
/// (data-model.md §PartySessionPrice).
class PartySessionPriceInput {
  const PartySessionPriceInput({
    required this.drinkPresetId,
    this.priceMinor,
    this.currency,
    this.priceTokens,
  });

  final String drinkPresetId;
  final int? priceMinor;
  final String? currency;
  final int? priceTokens;
}

/// The most recently *ended* session's pricing configuration, returned by
/// [PartySessionRepository.getLastSessionPricing] for the "copy from last
/// session" shortcut.
class LastSessionPricing {
  const LastSessionPricing({
    required this.prices,
    this.tokenName,
    this.tokenValueMinor,
    this.tokenValueCurrency,
  });

  final List<PartySessionPrice> prices;
  final String? tokenName;
  final int? tokenValueMinor;
  final String? tokenValueCurrency;
}

/// The price to snapshot onto a [DrinkEntry], returned by
/// [PartySessionRepository.resolvePrice]. Exactly one of ([priceMinor] +
/// [currency]) or [priceTokens] is set, mirroring [DrinkEntry]'s own mutual
/// exclusivity — or all fields are null when neither a regular price nor an
/// override applies.
class ResolvedDrinkPrice {
  const ResolvedDrinkPrice({
    this.priceMinor,
    this.currency,
    this.priceTokens,
    this.tokenValueMinor,
    this.tokenValueCurrency,
  });

  final int? priceMinor;
  final String? currency;
  final int? priceTokens;
  final int? tokenValueMinor;
  final String? tokenValueCurrency;
}
