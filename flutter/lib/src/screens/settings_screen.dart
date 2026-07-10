import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/drink_preset.dart';
import '../models/user_preferences.dart';
import '../models/user_profile.dart';
import '../repository/providers.dart';
import '../services/format_service.dart';
import '../theme/color_tokens.dart';
import 'manage_drinks_screen.dart';

/// S4 — Settings screen.
///
/// Reached by tapping the gear icon in the header of any top-level tab
/// screen. Groups and order are canonical per user-experience.md S4 /
/// features.md F6: Hydration, Reminders, Drinks, Profile, Party Mode,
/// Display & format, About. Every write goes through
/// [PreferencesRepository] — no Drift types reach this file.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(userPreferencesProvider);
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: prefsAsync.when(
        data: (prefs) => profileAsync.when(
          data: (profile) => _SettingsBody(prefs: prefs, profile: profile),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Could not load profile: $e')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Could not load settings: $e')),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body — composes the seven canonical S4 groups
// ---------------------------------------------------------------------------

class _SettingsBody extends ConsumerWidget {
  const _SettingsBody({required this.prefs, required this.profile});

  final UserPreferences prefs;
  final UserProfile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetsAsync = ref.watch(visibleNonAlcoholicPresetsProvider);
    final fmt = ref.watch(formatServiceProvider);
    final isImperial = prefs.units == 'imperial';

    return ListView(
      children: [
        _HydrationSection(prefs: prefs, isImperial: isImperial, fmt: fmt),
        _RemindersSection(prefs: prefs, presetsAsync: presetsAsync),
        const _DrinksSection(),
        _ProfileSection(profile: profile, isImperial: isImperial, fmt: fmt),
        _PartyModeSection(prefs: prefs, profile: profile),
        _DisplayFormatSection(prefs: prefs),
        const _AboutSection(),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Group 1 — Hydration
// ---------------------------------------------------------------------------

class _HydrationSection extends ConsumerWidget {
  const _HydrationSection({
    required this.prefs,
    required this.isImperial,
    required this.fmt,
  });

  final UserPreferences prefs;
  final bool isImperial;
  final FormatService? fmt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(preferencesRepositoryProvider);
    final goalDisplay = isImperial
        ? _fmt1(mlToFlOz(prefs.dailyGoalMl.toDouble()))
        : prefs.dailyGoalMl.toString();
    final goalSuffix = isImperial ? 'fl oz' : 'ml';

    return _SettingsSection(
      title: 'Hydration',
      children: [
        _SettingsNumberField(
          key: const Key('settings_daily_goal_field'),
          label: 'Daily goal',
          suffixText: goalSuffix,
          caption: fmt?.formatLargeVolume(prefs.dailyGoalMl.toDouble()),
          initialValue: goalDisplay,
          onSubmitted: (text) {
            final value = double.tryParse(text.trim());
            if (value == null || value <= 0) return;
            final ml = isImperial ? flOzToMl(value) : value.roundToDouble();
            repo.updateDailyGoal(ml.round());
          },
        ),
        ListTile(
          key: const Key('settings_day_boundary_tile'),
          title: const Text('Day boundary'),
          subtitle: Text(_hourLabel(prefs.dayBoundaryHour)),
          trailing: DropdownButton<int>(
            key: const Key('settings_day_boundary_dropdown'),
            value: prefs.dayBoundaryHour,
            items: _hourItems(),
            onChanged: (h) {
              if (h != null) repo.updateDayBoundaryHour(h);
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Group 2 — Reminders
// ---------------------------------------------------------------------------

class _RemindersSection extends ConsumerWidget {
  const _RemindersSection({required this.prefs, required this.presetsAsync});

  final UserPreferences prefs;
  final AsyncValue<List<DrinkPreset>> presetsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(preferencesRepositoryProvider);

    return _SettingsSection(
      title: 'Reminders',
      children: [
        SwitchListTile(
          key: const Key('settings_reminder_master_switch'),
          title: const Text('Reminders'),
          value: prefs.reminderEnabled,
          onChanged: (v) => repo.updateReminderSchedule(reminderEnabled: v),
        ),
        ListTile(
          title: const Text('Active hours'),
          subtitle: Text(
            '${_hourLabel(prefs.reminderStartHour)} – '
            '${_hourLabel(prefs.reminderEndHour)}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<int>(
                key: const Key('settings_reminder_start_hour'),
                value: prefs.reminderStartHour,
                items: _hourItems(),
                onChanged: (h) {
                  if (h != null) repo.updateReminderSchedule(startHour: h);
                },
              ),
              const SizedBox(width: 8),
              DropdownButton<int>(
                key: const Key('settings_reminder_end_hour'),
                value: prefs.reminderEndHour,
                items: _hourItems(),
                onChanged: (h) {
                  if (h != null) repo.updateReminderSchedule(endHour: h);
                },
              ),
            ],
          ),
        ),
        _SettingsNumberField(
          key: const Key('settings_reminder_interval_field'),
          label: 'Interval',
          suffixText: 'min',
          initialValue: prefs.reminderIntervalMin.toString(),
          onSubmitted: (text) {
            final v = int.tryParse(text.trim());
            if (v == null || v <= 0) return;
            repo.updateReminderSchedule(intervalMin: v);
          },
        ),
        SwitchListTile(
          key: const Key('settings_inactivity_switch'),
          title: const Text('Inactivity reminder'),
          value: prefs.inactivityReminderEnabled,
          onChanged: (v) =>
              repo.updateNotificationToggles(inactivityReminderEnabled: v),
        ),
        SwitchListTile(
          key: const Key('settings_weekly_summary_switch'),
          title: const Text('Weekly summary'),
          value: prefs.weeklySummaryEnabled,
          onChanged: (v) =>
              repo.updateNotificationToggles(weeklySummaryEnabled: v),
        ),
        presetsAsync.when(
          data: (presets) {
            final validId =
                presets.any((p) => p.id == prefs.defaultDrinkPresetId)
                    ? prefs.defaultDrinkPresetId
                    : null;
            return ListTile(
              title: const Text('Default drink'),
              trailing: DropdownButton<String?>(
                key: const Key('settings_default_drink_dropdown'),
                value: validId,
                hint: const Text('Glass of water'),
                items: [
                  const DropdownMenuItem<String?>(
                    child: Text('Glass of water (default)'),
                  ),
                  ...presets.map(
                    (p) => DropdownMenuItem<String?>(
                      value: p.id,
                      child: Text(p.name),
                    ),
                  ),
                ],
                onChanged: (id) => repo.updateDefaultDrinkPreset(id),
              ),
            );
          },
          loading: () => const ListTile(
            title: Text('Default drink'),
            trailing: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (e, st) => const ListTile(
            title: Text('Default drink'),
            subtitle: Text('Could not load drink presets.'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Group 3 — Drinks
// ---------------------------------------------------------------------------

class _DrinksSection extends StatelessWidget {
  const _DrinksSection();

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: 'Drinks',
      children: [
        ListTile(
          key: const Key('settings_manage_drinks_tile'),
          title: const Text('Manage drinks'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ManageDrinksScreen()),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Group 4 — Profile
// ---------------------------------------------------------------------------

class _ProfileSection extends ConsumerWidget {
  const _ProfileSection({
    required this.profile,
    required this.isImperial,
    required this.fmt,
  });

  final UserProfile? profile;
  final bool isImperial;
  final FormatService? fmt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (profile == null) {
      return const _SettingsSection(
        title: 'Profile',
        children: [ListTile(title: Text('Profile not set up yet.'))],
      );
    }
    final p = profile!;
    final repo = ref.read(preferencesRepositoryProvider);

    void save(UserProfile Function(UserProfile) update) {
      repo.upsertProfile(update(p));
    }

    final gender = p.gender ?? 'unspecified';
    final weightDisplay = p.weightKg == null
        ? ''
        : (isImperial
            ? _fmt1(kgToLb(p.weightKg!))
            : p.weightKg!.toStringAsFixed(1));
    final weightSuffix = isImperial ? 'lb' : 'kg';

    return _SettingsSection(
      title: 'Profile',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gender', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _GenderChip(
                    key: const Key('settings_gender_male'),
                    label: 'Male',
                    value: 'male',
                    groupValue: gender,
                    onChanged: (v) => save((pr) => pr.copyWith(gender: v)),
                  ),
                  _GenderChip(
                    key: const Key('settings_gender_female'),
                    label: 'Female',
                    value: 'female',
                    groupValue: gender,
                    onChanged: (v) => save((pr) => pr.copyWith(gender: v)),
                  ),
                  _GenderChip(
                    key: const Key('settings_gender_unspecified'),
                    label: 'Prefer not to say',
                    value: 'unspecified',
                    groupValue: gender,
                    onChanged: (v) => save((pr) => pr.copyWith(gender: v)),
                  ),
                ],
              ),
            ],
          ),
        ),
        _SettingsNumberField(
          key: const Key('settings_weight_field'),
          label: 'Weight',
          suffixText: weightSuffix,
          caption: p.weightKg == null ? null : fmt?.formatMass(p.weightKg!),
          initialValue: weightDisplay,
          onSubmitted: (text) {
            final v = double.tryParse(text.trim());
            if (v == null || v <= 0) return;
            final kg = isImperial ? lbToKg(v) : v;
            save((pr) => pr.copyWith(weightKg: kg));
          },
        ),
        _HeightEditor(
          key: const Key('settings_height_editor'),
          heightCm: p.heightCm,
          isImperial: isImperial,
          caption: p.heightCm == null ? null : fmt?.formatHeight(p.heightCm!),
          onChanged: (cm) => save((pr) => pr.copyWith(heightCm: cm)),
        ),
        _BirthDateTile(
          value: p.birthDate,
          onChanged: (d) => save(
            (pr) => pr.copyWith(birthDate: d == null ? null : _formatDate(d)),
          ),
        ),
      ],
    );
  }
}

class _GenderChip extends StatelessWidget {
  const _GenderChip({
    super.key,
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = groupValue == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onChanged(value),
      selectedColor: kColorAzure.withAlpha(51),
      checkmarkColor: kColorAzure,
    );
  }
}

class _BirthDateTile extends StatelessWidget {
  const _BirthDateTile({required this.value, required this.onChanged});

  /// ISO-8601 date string, e.g. "1990-06-15".
  final String? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = value == null ? 'Not set' : value!;
    return ListTile(
      key: const Key('settings_birth_date_tile'),
      title: const Text('Birthday'),
      subtitle: Text(label),
      trailing: const Icon(Icons.calendar_today_outlined),
      onTap: () async {
        final initial = value == null ? DateTime(1990) : DateTime.parse(value!);
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Group 5 — Party Mode
// ---------------------------------------------------------------------------

class _PartyModeSection extends ConsumerWidget {
  const _PartyModeSection({required this.prefs, required this.profile});

  final UserPreferences prefs;
  final UserProfile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final birthDateStr = profile?.birthDate;

    if (birthDateStr == null) {
      return const _SettingsSection(
        title: 'Party Mode',
        children: [
          ListTile(
            key: Key('settings_party_mode_no_birthdate'),
            title: Text('Party Mode requires your birthday.'),
            subtitle: Text(
              'Set your birthday in Profile above to enable Party Mode.',
            ),
            leading: Icon(Icons.info_outline, color: kColorWarning),
          ),
        ],
      );
    }

    final birthDate = DateTime.parse(birthDateStr);
    final age = ageYearsFromBirthDate(
      birthDate: birthDate,
      today: DateTime.now(),
    );

    if (age < 18) {
      return const _SettingsSection(
        title: 'Party Mode',
        children: [
          ListTile(
            key: Key('settings_party_mode_under_18'),
            title: Text('Party Mode requires you to be 18 or older.'),
            subtitle: Text(
              'If you entered your birthday incorrectly, you can update it above.',
            ),
            leading: Icon(Icons.info_outline, color: kColorWarning),
          ),
        ],
      );
    }

    final repo = ref.read(preferencesRepositoryProvider);

    return _SettingsSection(
      title: 'Party Mode',
      children: [
        _SettingsNumberField(
          key: const Key('settings_bac_cap_field'),
          label: 'Personal cap (optional)',
          suffixText: 'g/L',
          initialValue: prefs.bacCapGramsPerL?.toString() ?? '',
          onSubmitted: (text) {
            final trimmed = text.trim();
            if (trimmed.isEmpty) {
              repo.updateBacCap(null);
              return;
            }
            final v = double.tryParse(trimmed);
            if (v != null && v > 0) repo.updateBacCap(v);
          },
        ),
        SwitchListTile(
          key: const Key('settings_approaching_cap_switch'),
          title: const Text('Approaching-cap notification'),
          value: prefs.approachingCapNotifEnabled,
          onChanged: (v) =>
              repo.updatePartyModeSettings(approachingCapNotifEnabled: v),
        ),
        SwitchListTile(
          key: const Key('settings_sober_estimate_switch'),
          title: const Text('Sober-estimate notification'),
          value: prefs.soberEstimateNotifEnabled,
          onChanged: (v) =>
              repo.updatePartyModeSettings(soberEstimateNotifEnabled: v),
        ),
        SwitchListTile(
          key: const Key('settings_bac_lock_screen_switch'),
          title: const Text('Show BAC on lock screen'),
          value: prefs.bacOnLockScreenEnabled,
          onChanged: (v) =>
              repo.updatePartyModeSettings(bacOnLockScreenEnabled: v),
        ),
        const ListTile(
          key: Key('settings_legal_limits_info'),
          title: Text('Reference legal limits'),
          subtitle: Text(
            'NL: 0.5 g/L (experienced) / 0.2 g/L (novice). Many EU countries: '
            '0.5 g/L. This is a personal goal, not a safety threshold — the '
            'estimate is never an indicator of fitness to drive. Always '
            'follow local law.',
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Group 6 — Display & format
// ---------------------------------------------------------------------------

class _DisplayFormatSection extends ConsumerWidget {
  const _DisplayFormatSection({required this.prefs});

  final UserPreferences prefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(preferencesRepositoryProvider);

    return _SettingsSection(
      title: 'Display & format',
      children: [
        ListTile(
          title: const Text('Units'),
          trailing: SegmentedButton<String>(
            key: const Key('settings_units_segmented'),
            segments: const [
              ButtonSegment(value: 'metric', label: Text('Metric')),
              ButtonSegment(value: 'imperial', label: Text('Imperial')),
            ],
            selected: {prefs.units},
            onSelectionChanged: (s) => repo.updateUnits(s.first),
          ),
        ),
        ListTile(
          title: const Text('Currency'),
          trailing: DropdownButton<String>(
            key: const Key('settings_currency_dropdown'),
            value: prefs.currency,
            items: const [
              DropdownMenuItem(value: 'EUR', child: Text('EUR')),
              DropdownMenuItem(value: 'USD', child: Text('USD')),
              DropdownMenuItem(value: 'GBP', child: Text('GBP')),
            ],
            onChanged: (v) {
              if (v != null) repo.updateCurrency(v);
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Group 7 — About
// ---------------------------------------------------------------------------

class _AboutSection extends ConsumerWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(appInfoServiceProvider);
    return _SettingsSection(
      title: 'About',
      children: [
        FutureBuilder<String>(
          future: service.versionString(),
          builder: (context, snapshot) {
            return ListTile(
              key: const Key('settings_about_version_tile'),
              title: const Text('Version'),
              subtitle: Text(snapshot.data ?? '…'),
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared building blocks
// ---------------------------------------------------------------------------

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: kColorAzure,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ...children,
        const Divider(height: 1),
      ],
    );
  }
}

/// A numeric text field that commits its value via [onSubmitted] (keyboard
/// "done" or an explicit call in tests) rather than on every keystroke, so a
/// half-typed number is never persisted. An optional [caption] shows the
/// FormatService-rendered current value beneath the field.
class _SettingsNumberField extends StatefulWidget {
  const _SettingsNumberField({
    super.key,
    required this.label,
    required this.suffixText,
    required this.initialValue,
    required this.onSubmitted,
    this.caption,
  });

  final String label;
  final String suffixText;
  final String initialValue;
  final ValueChanged<String> onSubmitted;
  final String? caption;

  @override
  State<_SettingsNumberField> createState() => _SettingsNumberFieldState();
}

class _SettingsNumberFieldState extends State<_SettingsNumberField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode()..addListener(_commitOnBlur);
  }

  void _commitOnBlur() {
    if (!_focusNode.hasFocus) widget.onSubmitted(_controller.text);
  }

  @override
  void didUpdateWidget(covariant _SettingsNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && widget.initialValue != oldWidget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_commitOnBlur);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onSubmitted: widget.onSubmitted,
            decoration: InputDecoration(
              labelText: widget.label,
              suffixText: widget.suffixText,
              border: const OutlineInputBorder(),
            ),
          ),
          if (widget.caption != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                'Currently: ${widget.caption}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

/// Height editor — a single cm field in metric mode, or feet + inches fields
/// in imperial mode (the Parity Rulebook height conversion is feet/inches,
/// not decimal feet).
class _HeightEditor extends StatefulWidget {
  const _HeightEditor({
    super.key,
    required this.heightCm,
    required this.isImperial,
    required this.onChanged,
    this.caption,
  });

  final double? heightCm;
  final bool isImperial;
  final ValueChanged<double?> onChanged;
  final String? caption;

  @override
  State<_HeightEditor> createState() => _HeightEditorState();
}

class _HeightEditorState extends State<_HeightEditor> {
  late TextEditingController _cmCtrl;
  late TextEditingController _ftCtrl;
  late TextEditingController _inCtrl;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    final cm = widget.heightCm;
    _cmCtrl = TextEditingController(
      text: cm == null ? '' : cm.toStringAsFixed(1),
    );
    if (cm != null) {
      final (:feet, :inches) = cmToFtIn(cm);
      _ftCtrl = TextEditingController(text: feet.toString());
      _inCtrl = TextEditingController(text: inches.toString());
    } else {
      _ftCtrl = TextEditingController();
      _inCtrl = TextEditingController();
    }
  }

  @override
  void didUpdateWidget(covariant _HeightEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.heightCm != oldWidget.heightCm ||
        widget.isImperial != oldWidget.isImperial) {
      _cmCtrl.dispose();
      _ftCtrl.dispose();
      _inCtrl.dispose();
      _initControllers();
    }
  }

  @override
  void dispose() {
    _cmCtrl.dispose();
    _ftCtrl.dispose();
    _inCtrl.dispose();
    super.dispose();
  }

  void _submitMetric(String text) {
    final v = double.tryParse(text.trim());
    widget.onChanged(v == null || v <= 0 ? null : v);
  }

  void _submitImperial([String? _]) {
    final ft = int.tryParse(_ftCtrl.text.trim()) ?? 0;
    final inch = int.tryParse(_inCtrl.text.trim()) ?? 0;
    if (ft == 0 && inch == 0) {
      widget.onChanged(null);
      return;
    }
    widget.onChanged(ftInToCm(ft, inch));
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.isImperial
        ? Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('settings_height_ft_field'),
                  controller: _ftCtrl,
                  keyboardType: TextInputType.number,
                  onSubmitted: _submitImperial,
                  decoration: const InputDecoration(
                    labelText: 'Height (optional)',
                    suffixText: 'ft',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const Key('settings_height_in_field'),
                  controller: _inCtrl,
                  keyboardType: TextInputType.number,
                  onSubmitted: _submitImperial,
                  decoration: const InputDecoration(
                    suffixText: 'in',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          )
        : TextField(
            key: const Key('settings_height_cm_field'),
            controller: _cmCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onSubmitted: _submitMetric,
            decoration: const InputDecoration(
              labelText: 'Height (optional)',
              suffixText: 'cm',
              border: OutlineInputBorder(),
            ),
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          field,
          if (widget.caption != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                'Currently: ${widget.caption}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

String _hourLabel(int hour) => '${hour.toString().padLeft(2, '0')}:00';

List<DropdownMenuItem<int>> _hourItems() => List.generate(
      24,
      (h) => DropdownMenuItem(value: h, child: Text(_hourLabel(h))),
    );

String _fmt1(double value) => value.toStringAsFixed(1);

String _formatDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
