import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../models/beverage_type.dart';
import '../models/drink_entry.dart';
import '../models/drink_preset.dart';
import '../models/meal.dart';
import '../models/optional.dart';
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

  /// Reactive stream of every ended session, newest-ended-first — feeds the
  /// S7 "past sessions" list (user-experience.md §S7 → No active session —
  /// subsequent visits).
  Stream<List<PartySession>> watchEndedSessions() =>
      _db.watchEndedSessions().map((rows) => rows.map(_rowToSession).toList());

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
  ///
  /// [name] is the optional, skippable session name (party-session.md
  /// §Starting a session), normalised via [normalizePartySessionName] —
  /// unlike [tokenName] this is never rejected, only sanitised.
  Future<PartySession> startSession({
    DateTime? startedAt,
    bool useSessionPrices = false,
    String? tokenName,
    int? tokenValueMinor,
    String? tokenValueCurrency,
    String? name,
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
    final normalizedName = normalizePartySessionName(name);

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
          name: Value(normalizedName),
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
  /// If the session has **zero alcoholic drinks** at this moment (none
  /// in-session, none absorbed as orphans), it is discarded instead of ended
  /// — soft-deleted immediately, with no confirmation prompt, rather than
  /// getting an `endedAt`/`endReason` (party-session.md §Zero-drink sessions
  /// are never saved). This applies even if the session has meals logged —
  /// the check is drink-count-only.
  ///
  /// Throws [StateError] if [id] does not exist.
  Future<void> endSession(
    String id,
    PartySessionEndReason reason, {
    DateTime? now,
  }) async {
    final nowUtc = (now ?? DateTime.now()).toUtc();
    if (await _hasAlcoholicEntries(id)) {
      final rows = await _db.updatePartySessionFields(
        id,
        PartySessionsCompanion(
          endedAt: Value(nowUtc),
          endReason: Value(reason.stored),
          updatedAt: Value(nowUtc),
        ),
      );
      if (rows == 0) throw StateError('PartySession $id not found.');
    } else {
      final rows = await _db.softDeletePartySession(id, nowUtc);
      if (rows == 0) throw StateError('PartySession $id not found.');
    }
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
  /// §PartySession → Auto-end semantics. If the session has zero alcoholic
  /// drinks at its auto-end mark, it is discarded instead — same rule as the
  /// manual path in [endSession] (party-session.md §Zero-drink sessions are
  /// never saved).
  Future<void> checkAndApplyAutoEnd({DateTime? now}) async {
    final nowUtc = (now ?? DateTime.now()).toUtc();
    final active = await _db.getActiveSession();
    if (active == null) return;

    final autoEndAt = await _autoEndMark(active);
    if (!nowUtc.isBefore(autoEndAt)) {
      if (await _hasAlcoholicEntries(active.id)) {
        await _db.updatePartySessionFields(
          active.id,
          PartySessionsCompanion(
            endedAt: Value(autoEndAt),
            endReason: Value(PartySessionEndReason.autoTimeout.stored),
            updatedAt: Value(nowUtc),
          ),
        );
      } else {
        await _db.softDeletePartySession(active.id, nowUtc);
      }
    }
  }

  /// Deletes ended session [id] — the past-sessions list / S9 ended-header
  /// delete action (party-session.md §Deleting a session). Soft-deletes the
  /// [PartySession] row and detaches every [DrinkEntry] that belonged to it
  /// (`partySessionId = null`), turning them back into ordinary orphans. The
  /// drinks themselves are never deleted.
  ///
  /// Throws [StateError] if [id] does not exist, or if it is still the
  /// active session — only an ended session can be deleted (party-session.md:
  /// "there is no delete affordance on the active session; end it first").
  Future<void> deleteSession(String id, {DateTime? now}) async {
    final session = await _db.getPartySessionById(id);
    if (session == null) throw StateError('PartySession $id not found.');
    if (session.endedAt == null) {
      throw StateError(
        'PartySession $id is still active; end it before deleting.',
      );
    }

    final nowUtc = (now ?? DateTime.now()).toUtc();
    await _db.transaction(() async {
      await _db.softDeletePartySession(id, nowUtc);
      await _db.detachSessionEntries(id, nowUtc);
    });
  }

  Future<DateTime> _autoEndMark(PartySessionRow session) async {
    final last = await _db.getLastAlcoholicEntryInSession(
      session.id,
      _alcoholicTypeStrings,
    );
    final base = last?.consumedAt ?? session.startedAt;
    return base.add(_autoEndAfter);
  }

  /// Whether [sessionId] has at least one live alcoholic [DrinkEntry] —
  /// in-session or absorbed orphan, both of which carry `partySessionId ==
  /// sessionId` (party-session.md §Zero-drink sessions are never saved:
  /// "none logged in-session and none absorbed as orphans").
  Future<bool> _hasAlcoholicEntries(String sessionId) async {
    final last = await _db.getLastAlcoholicEntryInSession(
      sessionId,
      _alcoholicTypeStrings,
    );
    return last != null;
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

  /// Edits the last-logged meal's [size] (Party tab's meal indicator: "edit
  /// the last one" — party-session.md §Party tab during a session). Leaves
  /// [Meal.eatenAt] untouched — editing corrects a mis-picked size, not when
  /// the meal happened.
  ///
  /// Throws [StateError] if [id] does not exist.
  Future<void> updateMeal({
    required String id,
    required MealSize size,
    DateTime? now,
  }) async {
    final nowUtc = (now ?? DateTime.now()).toUtc();
    final rows = await _db.updateMealFields(
      id,
      MealsCompanion(size: Value(size.stored), updatedAt: Value(nowUtc)),
    );
    if (rows == 0) throw StateError('Meal $id not found.');
  }

  // ---------------------------------------------------------------------------
  // Drink entries
  // ---------------------------------------------------------------------------

  /// Logs an alcoholic drink into [sessionId], snapshotting preset values at
  /// the current time (log immutability — data-model.md §Snapshot semantics).
  ///
  /// [preset.beverageType] must be alcoholic (party-session.md: alcoholic
  /// types are "only logged during an active Party Session").
  ///
  /// [id] lets a caller generate the entry's id up front (C6: pop a sheet
  /// before the write settles, e.g. [LogDrinkSheet]'s advanced-editor
  /// confirm-only path attaching to an active session) — defaults to a fresh
  /// uuid, mirroring [DrinksRepository.logDrink]. [name] is a one-off,
  /// this-entry-only override (party-session.md §Logging an alcoholic drink
  /// (during a session)); defaults to [preset.name] when omitted.
  ///
  /// Money and tokens are mutually exclusive per drink (data-model.md
  /// §DrinkEntry): pass at most one of ([priceMinor] + [currency]) or
  /// ([priceTokens] + optionally [tokenValueMinor] + [tokenValueCurrency]).
  /// Throws [ArgumentError] on a mutually-exclusive or incomplete pricing
  /// combination, or if [preset.beverageType] is not alcoholic.
  ///
  /// [isManualPriceOverride] marks the price above as a deliberate,
  /// this-entry-only override (e.g. `PartyLogDrinkSheet`'s price field) as
  /// opposed to a price resolved the usual way via [resolvePrice] — it
  /// exempts this entry from future retroactive party-price sweeps
  /// (party-session.md §Editing prices during a session). Defaults to
  /// `false`.
  Future<DrinkEntry> logAlcoholicDrink({
    required DrinkPreset preset,
    required String sessionId,
    String? id,
    String? name,
    int? volumeMl,
    double? abvPercent,
    DateTime? consumedAt,
    int? priceMinor,
    String? currency,
    int? priceTokens,
    int? tokenValueMinor,
    String? tokenValueCurrency,
    bool isManualPriceOverride = false,
    DateTime? now,
  }) async {
    if (!preset.beverageType.isAlcoholic) {
      throw ArgumentError.value(
        preset.beverageType,
        'preset.beverageType',
        'Must be alcoholic to log into a Party Session',
      );
    }
    if (name != null) {
      final result = validatePresetName(name);
      if (!result.isValid) {
        throw ArgumentError.value(name, 'name', result.error);
      }
      name = normalizeNfc(name);
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
    final entryId = id ?? _uuid.v4();
    final resolvedName = name ?? preset.name;
    final resolvedAbv = abvPercent ?? preset.abvPercent;
    await _db.insertDrinkEntry(
      DrinkEntriesCompanion.insert(
        id: entryId,
        name: Value(resolvedName),
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
        presetId: Value(preset.id),
        manualPriceOverride: Value(isManualPriceOverride),
        consumedAt: consumedAtUtc,
        createdAt: nowUtc,
        updatedAt: nowUtc,
      ),
    );
    // Auto-end trigger point: "a drink is logged" (party-session.md §Auto-end
    // is computed lazily). Runs after the insert so a backdated consumedAt
    // more than 12h in the past can retroactively close the session it was
    // just logged into, same as any other lazy check.
    await checkAndApplyAutoEnd(now: nowUtc);
    return DrinkEntry(
      id: entryId,
      name: resolvedName,
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
      presetId: preset.id,
      manualPriceOverride: isManualPriceOverride,
      consumedAt: consumedAtUtc,
      createdAt: nowUtc,
      updatedAt: nowUtc,
    );
  }

  /// Reactive stream of live entries belonging to [sessionId], oldest first.
  Stream<List<DrinkEntry>> watchSessionEntries(String sessionId) => _db
      .watchSessionEntries(sessionId)
      .map((rows) => rows.map(_rowToEntry).toList());

  /// Edits a session-attached alcoholic [DrinkEntry] — S9's active-mode edit
  /// affordance (user-experience.md §S9: "Editable fields are volume, name,
  /// ABV, price, and time — mirroring S6's edit affordance"). Unlike S6's
  /// [DrinksRepository.updateDrinkEntry] (volume/time only), this also
  /// allows a direct, deliberate user edit of the snapshot fields — permitted
  /// by data-model.md §Snapshot semantics ("The only path to change a
  /// DrinkEntry is a direct, deliberate user edit of that entry").
  ///
  /// [priceMinor]/[currency] are a **one-off, this-entry-only** override
  /// (same as at log time — party-session.md §Logging an alcoholic drink);
  /// passing [priceMinor] as [Optional.value] always writes a money price and
  /// clears any token price on this entry (money/tokens stay mutually
  /// exclusive — data-model.md §DrinkEntry), since the edit form only offers
  /// a money field. Leaving [priceMinor] as the default [Optional.absent]
  /// leaves this entry's existing price (money or tokens) untouched.
  ///
  /// Touching [priceMinor] (present, whether setting or clearing) also sets
  /// `manualPriceOverride`, exempting this entry from future retroactive
  /// party-price sweeps (party-session.md §Editing prices during a session)
  /// — a deliberate per-entry edit always wins over the session-wide table.
  ///
  /// Throws [ArgumentError] if [volumeMl] is provided and `< 1`, if
  /// [abvPercent] is provided and `<= 0`, if [name] fails
  /// [validatePresetName], or if [priceMinor] is present with a null value
  /// but [currency] is absent (or vice versa) — clearing the price requires
  /// clearing both together, mirroring [logAlcoholicDrink]'s own pairing
  /// rule.
  Future<void> updateAlcoholicEntry({
    required String id,
    int? volumeMl,
    String? name,
    double? abvPercent,
    DateTime? consumedAt,
    Optional<int?> priceMinor = const Optional.absent(),
    Optional<String?> currency = const Optional.absent(),
    DateTime? now,
  }) async {
    if (volumeMl != null && volumeMl < 1) {
      throw ArgumentError.value(volumeMl, 'volumeMl', 'must be ≥ 1 ml');
    }
    if (abvPercent != null && abvPercent <= 0) {
      throw ArgumentError.value(abvPercent, 'abvPercent', 'must be > 0');
    }
    var normalizedName = name;
    if (name != null) {
      final result = validatePresetName(name);
      if (!result.isValid) {
        throw ArgumentError.value(name, 'name', result.error);
      }
      normalizedName = normalizeNfc(name);
    }
    if (priceMinor.isPresent != currency.isPresent) {
      throw ArgumentError(
        'priceMinor and currency must be set or cleared together',
      );
    }
    if (priceMinor.isPresent &&
        (priceMinor.value == null) != (currency.value == null)) {
      throw ArgumentError(
        'currency is required when priceMinor is set, and must be null '
        'otherwise',
      );
    }

    final nowUtc = (now ?? DateTime.now()).toUtc();
    final rows = await _db.updateDrinkEntryFields(
      id,
      DrinkEntriesCompanion(
        name: normalizedName != null
            ? Value(normalizedName)
            : const Value.absent(),
        volumeMl: volumeMl != null ? Value(volumeMl) : const Value.absent(),
        abvPercent:
            abvPercent != null ? Value(abvPercent) : const Value.absent(),
        consumedAt: consumedAt != null
            ? Value(consumedAt.toUtc())
            : const Value.absent(),
        priceMinor: priceMinor.isPresent
            ? Value(priceMinor.value)
            : const Value.absent(),
        currency:
            priceMinor.isPresent ? Value(currency.value) : const Value.absent(),
        // Money and tokens are mutually exclusive per drink — a one-off money
        // override on this entry must clear any prior token price.
        priceTokens:
            priceMinor.isPresent ? const Value(null) : const Value.absent(),
        tokenValueMinor:
            priceMinor.isPresent ? const Value(null) : const Value.absent(),
        tokenValueCurrency:
            priceMinor.isPresent ? const Value(null) : const Value.absent(),
        manualPriceOverride:
            priceMinor.isPresent ? const Value(true) : const Value.absent(),
        updatedAt: Value(nowUtc),
      ),
    );
    if (rows == 0) throw StateError('DrinkEntry $id not found.');
  }

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
  ///
  /// Also retroactively sweeps the resulting price onto every already-logged,
  /// non-manually-overridden [DrinkEntry] in [sessionId] for each touched
  /// `drinkPresetId` (issue #87, party-session.md §Editing prices during a
  /// session) — the swept value is whatever [resolvePrice] would produce for
  /// that preset right now, so this stays correct whether [prices] sets an
  /// override, clears one back to the regular price, or the session has
  /// `useSessionPrices` off.
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

      // Retroactive sweep (issue #87, party-session.md §Editing prices
      // during a session): already-logged entries for each touched preset
      // pick up the price a fresh log action would resolve to right now, so
      // a party-price edit doesn't leave stale prices on drinks logged
      // before the edit. Entries carrying a manual per-entry override
      // (PartyLogDrinkSheet's price field, or S9's per-entry price edit) are
      // skipped — a deliberate one-off edit always wins over the
      // session-wide table.
      final session = await _db.getPartySessionById(sessionId);
      if (session != null) {
        for (final p in prices) {
          final resolved = await _resolveSweptPrice(session: session, input: p);
          if (resolved == null) continue;
          await _db.sweepSessionEntryPrices(
            sessionId: sessionId,
            presetId: p.drinkPresetId,
            companion: DrinkEntriesCompanion(
              priceMinor: Value(resolved.priceMinor),
              currency: Value(resolved.currency),
              priceTokens: Value(resolved.priceTokens),
              tokenValueMinor: Value(resolved.tokenValueMinor),
              tokenValueCurrency: Value(resolved.tokenValueCurrency),
              updatedAt: Value(nowUtc),
            ),
          );
        }
      }
    });
  }

  /// Resolves the price a fresh [logAlcoholicDrink] call would produce right
  /// now for [input]'s preset — the retroactive sweep's per-preset price,
  /// mirroring [resolvePrice]'s own branching. Unlike [resolvePrice], this
  /// works from the just-written override [input] directly (the write and
  /// the sweep must agree within the same [setSessionPrices] transaction)
  /// and looks the preset up by id, since the sweep only has a
  /// `drinkPresetId`, not a full [DrinkPreset].
  ///
  /// Returns null when there's nothing to sweep with — [session] has
  /// `useSessionPrices == false` (or [input] carries no override value) and
  /// the preset can't be found to read its regular price from.
  Future<ResolvedDrinkPrice?> _resolveSweptPrice({
    required PartySessionRow session,
    required PartySessionPriceInput input,
  }) async {
    final hasOverrideValue =
        input.priceMinor != null || input.priceTokens != null;
    if (session.useSessionPrices && hasOverrideValue) {
      if (input.priceTokens != null) {
        return ResolvedDrinkPrice(
          priceTokens: input.priceTokens,
          tokenValueMinor: session.tokenValueMinor,
          tokenValueCurrency: session.tokenValueCurrency,
        );
      }
      return ResolvedDrinkPrice(
        priceMinor: input.priceMinor,
        currency: input.currency,
      );
    }
    final preset = await _db.getPresetById(input.drinkPresetId);
    if (preset == null) return null;
    return ResolvedDrinkPrice(
      priceMinor: preset.regularPriceMinor,
      currency: preset.regularCurrency,
    );
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

  /// Sets or clears the session's optional display name — settable at start
  /// ([startSession]) and editable at any later point too (party-session.md
  /// §Starting a session: "from the Party tab while active, or from S9's
  /// ended-mode header once it has ended"). [name] is sanitised via
  /// [normalizePartySessionName] (Parity Rulebook → "PartySession name") —
  /// never rejected, only stripped/trimmed/capped; a null or
  /// empty-after-trim [name] clears it.
  ///
  /// Throws [StateError] if [sessionId] does not exist.
  Future<void> updateSessionName(
    String sessionId,
    String? name, {
    DateTime? now,
  }) async {
    final normalizedName = normalizePartySessionName(name);
    final nowUtc = (now ?? DateTime.now()).toUtc();
    final rows = await _db.updatePartySessionFields(
      sessionId,
      PartySessionsCompanion(
        name: Value(normalizedName),
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
  // History — alcohol charts + day drill-down (issue #26)
  // ---------------------------------------------------------------------------

  /// Reactive stream of live sessions whose window overlaps
  /// `[rangeStart, rangeEnd)`, ordered by [PartySession.startedAt] — feeds
  /// the History alcohol section's conditional-visibility check, the session
  /// overlay band, and BAC-peak sampling (F4/#26).
  Stream<List<PartySession>> watchSessionsInRange(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) =>
      _db
          .watchSessionsOverlapping(rangeStart.toUtc(), rangeEnd.toUtc())
          .map((rows) => rows.map(_rowToSession).toList());

  /// One-shot read of every live alcoholic entry belonging to any of
  /// [sessionIds] — feeds the BAC-peak-per-day sampler (F4/#26), which needs
  /// each session's full entry list regardless of the sampled day/range.
  Future<List<DrinkEntry>> getEntriesForSessions(
    List<String> sessionIds,
  ) async {
    final rows = await _db.getEntriesForSessions(sessionIds);
    return rows.map(_rowToEntry).toList();
  }

  /// One-shot read of every live meal belonging to any of [sessionIds] — see
  /// [getEntriesForSessions].
  Future<List<Meal>> getMealsForSessions(List<String> sessionIds) async {
    final rows = await _db.getMealsForSessions(sessionIds);
    return rows.map(_rowToMeal).toList();
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
        name: row.name,
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
        presetId: row.presetId,
        manualPriceOverride: row.manualPriceOverride,
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
