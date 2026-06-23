import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/user_profile.dart';
import '../../repository/providers.dart';
import '../../services/notification_permission_service.dart';
import '../../theme/color_tokens.dart';
import '../../theme/motion_tokens.dart';
import '../../theme/reduce_motion.dart';

/// 5-step onboarding wizard (S5).
///
/// Shown by [_AppGate] when [UserPreferences.username] is null.
/// On completion, calls [PreferencesRepository.completeOnboarding] which writes
/// username + dailyGoalMl + UserProfile atomically. The username write acts as
/// the commit marker: once set, [_AppGate] routes to [AppShell] automatically.
///
/// Steps:
///   1. Welcome
///   2. Username         (progress dot 1/4)
///   3. Personal info    (progress dot 2/4)
///   4. Daily goal       (progress dot 3/4)
///   5. Notifications    (progress dot 4/4)
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final _pageController = PageController();
  final _notificationService = const NotificationPermissionService();

  // Stable UUID for the profile row — generated once per onboarding session.
  final String _profileId = const Uuid().v4();
  int _page = 0;

  // Step 2 — Username
  final _usernameController = TextEditingController();
  String? _usernameError;

  // Step 3 — Personal Info
  String? _gender;
  final _weightController = TextEditingController(text: '70');
  final _heightController = TextEditingController();
  DateTime? _birthDate;

  // Step 4 — Daily Goal
  final _goalController = TextEditingController(
    text: dailyGoalMl(70.0).toString(),
  );

  @override
  void dispose() {
    _pageController.dispose();
    _usernameController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  bool get _usernameIsValid =>
      validateUsername(normalizeNfc(_usernameController.text)).isValid;

  int get _parsedGoal {
    final n = int.tryParse(_goalController.text.trim());
    return (n != null && n > 0) ? n : dailyGoalMl(70.0);
  }

  void _syncGoalFromWeight() {
    final w = double.tryParse(_weightController.text.trim());
    if (w != null && w > 0) {
      _goalController.text = dailyGoalMl(w).toString();
    }
  }

  Future<void> _animateTo(int page) async {
    final duration =
        ReduceMotion.isEnabled(context) ? Duration.zero : MotionTokens.standard;
    await _pageController.animateToPage(
      page,
      duration: duration,
      curve: MotionTokens.easing,
    );
    if (mounted) setState(() => _page = page);
  }

  Future<void> _onNext() async {
    // Recompute goal from weight before leaving the personal-info step.
    if (_page == 2) _syncGoalFromWeight();
    await _animateTo(_page + 1);
  }

  Future<void> _onDone() async {
    final now = DateTime.now().toUtc();
    final weightKg = double.tryParse(_weightController.text.trim());
    final heightCm = double.tryParse(_heightController.text.trim());

    final profile = UserProfile(
      id: _profileId,
      gender: _gender,
      weightKg: weightKg,
      heightCm: heightCm,
      birthDate: _birthDate == null ? null : _formatDate(_birthDate!),
      createdAt: now,
      updatedAt: now,
    );

    try {
      await ref.read(preferencesRepositoryProvider).completeOnboarding(
            username: _usernameController.text,
            profile: profile,
            dailyGoalMl: _parsedGoal,
          );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    }
    // _AppGate reacts to userPreferencesProvider emitting username != null
    // and replaces OnboardingFlow with AppShell automatically.
  }

  static String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (_page > 0) _ProgressDots(current: _page - 1, total: 4),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  const _WelcomePage(),
                  _UsernamePage(
                    controller: _usernameController,
                    error: _usernameError,
                    onChanged: (v) {
                      final result = validateUsername(normalizeNfc(v));
                      setState(() {
                        _usernameError = result.isValid ? null : result.error;
                      });
                    },
                  ),
                  _PersonalInfoPage(
                    gender: _gender,
                    onGenderChanged: (g) => setState(() => _gender = g),
                    weightController: _weightController,
                    heightController: _heightController,
                    birthDate: _birthDate,
                    onBirthDateChanged: (d) => setState(() => _birthDate = d),
                  ),
                  _GoalPage(controller: _goalController),
                  _NotificationsPage(service: _notificationService),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: _buildCta(),
            ),
          ],
        ),
      ),
    );
  }

  static final _ctaStyle = FilledButton.styleFrom(
    backgroundColor: kColorHoney,
    foregroundColor: Colors.white,
    minimumSize: const Size.fromHeight(48),
  );

  Widget _buildCta() {
    if (_page == 0) {
      return FilledButton(
        key: const Key('onboarding_cta_welcome'),
        style: _ctaStyle,
        onPressed: _onNext,
        child: const Text("Let's start"),
      );
    }
    if (_page == 4) {
      return FilledButton(
        key: const Key('onboarding_cta_done'),
        style: _ctaStyle,
        onPressed: _onDone,
        child: const Text('Done'),
      );
    }
    return FilledButton(
      key: const Key('onboarding_cta_next'),
      style: _ctaStyle,
      onPressed: (_page == 1 && !_usernameIsValid) ? null : _onNext,
      child: const Text('Next'),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1 — Welcome
// ---------------------------------------------------------------------------

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.water_drop_rounded, size: 80, color: kColorAzure),
          const SizedBox(height: 32),
          Text(
            'Welcome to Drinks Mate',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Track your daily hydration. Stay healthy, stay on track.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2 — Username
// ---------------------------------------------------------------------------

class _UsernamePage extends StatelessWidget {
  const _UsernamePage({
    required this.controller,
    required this.error,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String? error;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose a username',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '3–30 characters · letters, digits, and _ - . allowed',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          TextField(
            key: const Key('onboarding_username_field'),
            controller: controller,
            autofocus: true,
            onChanged: onChanged,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Username',
              errorText: error,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 3 — Personal Info
// ---------------------------------------------------------------------------

class _PersonalInfoPage extends StatelessWidget {
  const _PersonalInfoPage({
    required this.gender,
    required this.onGenderChanged,
    required this.weightController,
    required this.heightController,
    required this.birthDate,
    required this.onBirthDateChanged,
  });

  final String? gender;
  final ValueChanged<String?> onGenderChanged;
  final TextEditingController weightController;
  final TextEditingController heightController;
  final DateTime? birthDate;
  final ValueChanged<DateTime?> onBirthDateChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About you', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'All fields are optional.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          Text('Gender', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _GenderChip(
                label: 'Male',
                value: 'male',
                groupValue: gender,
                onChanged: onGenderChanged,
              ),
              _GenderChip(
                label: 'Female',
                value: 'female',
                groupValue: gender,
                onChanged: onGenderChanged,
              ),
              _GenderChip(
                label: 'Prefer not to say',
                value: 'unspecified',
                groupValue: gender,
                onChanged: onGenderChanged,
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            key: const Key('onboarding_weight_field'),
            controller: weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Weight',
              suffixText: 'kg',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('onboarding_height_field'),
            controller: heightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Height',
              suffixText: 'cm',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          _BirthDateButton(value: birthDate, onChanged: onBirthDateChanged),
        ],
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  const _GenderChip({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String label;
  final String value;
  final String? groupValue;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = groupValue == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onChanged(selected ? null : value),
      selectedColor: kColorAzure.withAlpha(51),
      checkmarkColor: kColorAzure,
    );
  }
}

class _BirthDateButton extends StatelessWidget {
  const _BirthDateButton({required this.value, required this.onChanged});

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = value == null
        ? 'Date of birth (optional)'
        : '${value!.year.toString().padLeft(4, '0')}-'
            '${value!.month.toString().padLeft(2, '0')}-'
            '${value!.day.toString().padLeft(2, '0')}';

    return OutlinedButton.icon(
      key: const Key('onboarding_birth_date_button'),
      icon: const Icon(Icons.calendar_today_outlined),
      label: Text(label),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime(1990),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Step 4 — Daily Goal
// ---------------------------------------------------------------------------

class _GoalPage extends StatelessWidget {
  const _GoalPage({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your daily goal',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'We calculated this from your weight. Feel free to adjust.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          TextField(
            key: const Key('onboarding_goal_field'),
            controller: controller,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Daily goal',
              suffixText: 'ml',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 5 — Notifications
// ---------------------------------------------------------------------------

class _NotificationsPage extends StatefulWidget {
  const _NotificationsPage({required this.service});

  final NotificationPermissionService service;

  @override
  State<_NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<_NotificationsPage> {
  bool _requested = false;

  Future<void> _requestPermission() async {
    await widget.service.requestPermission();
    if (mounted) setState(() => _requested = true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stay on track',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Enable notifications to receive hydration reminders throughout the day.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          if (!_requested)
            OutlinedButton(
              key: const Key('onboarding_enable_notifications_button'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: const BorderSide(color: kColorAzure),
                foregroundColor: kColorAzure,
              ),
              onPressed: _requestPermission,
              child: const Text('Enable Notifications'),
            )
          else
            Row(
              children: [
                const Icon(Icons.check_circle_outline, color: kColorAzure),
                const SizedBox(width: 8),
                Text(
                  'Notifications set up',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: kColorAzure),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress indicator
// ---------------------------------------------------------------------------

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.current, required this.total});

  /// Zero-indexed current step within the progress section (steps 2–5).
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final duration =
        ReduceMotion.isEnabled(context) ? Duration.zero : MotionTokens.fast;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(total, (i) {
          final active = i == current;
          return AnimatedContainer(
            duration: duration,
            curve: MotionTokens.easing,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: active ? 20 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: active ? kColorAzure : kColorAzure.withAlpha(76),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }
}
