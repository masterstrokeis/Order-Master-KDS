import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/urgency_settings_controller.dart';
import '../../core/constants/kds_timing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/urgency_color_presets.dart';
import '../../core/utils/order_announcement.dart';
import '../../core/utils/order_title_number.dart';
import '../../models/server_config.dart';
import '../../models/urgency_settings.dart';
import '../../providers/providers.dart';
import '../../services/announcement_preference_service.dart';
import '../../services/order_update_pulse_preference_service.dart';
import '../../services/product_quantity_list_preference_service.dart';
import '../kitchen_display/widgets/dark_mode_toggle.dart';
import '../login/login_screen.dart';
import '../server_setup/server_setup_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final String? staffName = ref.watch(
      authControllerProvider.select(
        (AuthState s) => s.session?.staff.name ?? s.selectedStaffName,
      ),
    );

    return Scaffold(
      // Same as kitchen_display_screen: body tracks ThemeMode via scaffoldBackgroundColor.
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Always-dark chrome like kds_top_bar / product_sidebar — not theme-reactive.
      appBar: AppBar(
        backgroundColor: AppColors.chromeHeader,
        foregroundColor: AppColors.onStatusHeader,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Settings',
          style: AppTextStyles.headlineMd.copyWith(
            color: AppColors.onStatusHeader,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pageMargin),
        children: [
          const _SettingsSection(
            title: 'Appearance',
            child: _AppearanceSection(),
          ),
          const SizedBox(height: AppSpacing.gutter),
          const _SettingsSection(
            title: 'Order Timing',
            initiallyExpanded: false,
            child: _OrderTimingSection(),
          ),
          const SizedBox(height: AppSpacing.gutter),
          const _SettingsSection(
            title: 'Notifications',
            child: _NotificationsSection(),
          ),
          const SizedBox(height: AppSpacing.gutter),
          const _SettingsSection(
            title: 'Server',
            child: _ServerSection(),
          ),
          const SizedBox(height: AppSpacing.gutter),
          _SettingsSection(
            title: 'Account',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  staffName ?? '—',
                  style: AppTextStyles.bodyLg.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.gutter),
                OutlinedButton(
                  onPressed: () => _confirmLogout(context, ref),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.urgencyCritical,
                    side: const BorderSide(
                      color: AppColors.urgencyCritical,
                      width: 2,
                    ),
                    minimumSize: const Size.fromHeight(
                      AppSpacing.touchTargetMin,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppRadii.defaultRadius,
                      ),
                    ),
                  ),
                  child: Text(
                    'Log out',
                    style: AppTextStyles.bodyMd.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.urgencyCritical,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final ColorScheme dialogColors = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: dialogColors.surfaceContainerHigh,
          title: Text(
            'Log out?',
            style: AppTextStyles.headlineMd.copyWith(
              color: dialogColors.onSurface,
            ),
          ),
          content: Text(
            "You'll need to sign in again.",
            style: AppTextStyles.bodyMd.copyWith(
              color: dialogColors.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: AppTextStyles.bodyMd.copyWith(
                  color: dialogColors.onSurfaceVariant,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Log Out',
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.urgencyCritical,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(authControllerProvider.notifier).logout();
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const LoginScreen(),
      ),
      (Route<dynamic> route) => false,
    );
  }
}

class _ServerSection extends ConsumerWidget {
  const _ServerSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final ServerConfig? server = ref.watch(serverConfigProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          server?.hostPort ?? 'Not configured',
          key: const Key('server-current-address'),
          style: AppTextStyles.bodyLg.copyWith(color: colorScheme.onSurface),
        ),
        const SizedBox(height: AppSpacing.gutter),
        OutlinedButton(
          key: const Key('server-change-button'),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ServerSetupScreen(fromSettings: true),
              ),
            );
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.onSurface,
            side: BorderSide(color: colorScheme.outline, width: 2),
            minimumSize: const Size.fromHeight(AppSpacing.touchTargetMin),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.defaultRadius),
            ),
          ),
          child: Text(
            'Change server',
            style: AppTextStyles.bodyMd.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatefulWidget {
  const _SettingsSection({
    required this.title,
    this.child,
    this.initiallyExpanded = true,
  });

  final String title;
  final Widget? child;
  final bool initiallyExpanded;

  @override
  State<_SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<_SettingsSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Widget? sectionChild = widget.child;

    return Container(
      key: widget.title == 'Order Timing'
          ? const Key('order-timing-section')
          : null,
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            key: widget.title == 'Order Timing'
                ? const Key('order-timing-header')
                : null,
            behavior: HitTestBehavior.opaque,
            onTap: sectionChild != null ? _toggle : null,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: AppTextStyles.labelCaps.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                if (sectionChild != null)
                  AnimatedRotation(
                    turns: _expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.chevron_right,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (sectionChild != null)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.gutter),
                        sectionChild,
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool productListVisible = ref.watch(
      productQuantityListVisibleProvider,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DarkModeToggle(),
        const SizedBox(height: AppSpacing.gutter),
        const _OrderTitleNumberPicker(),
        const SizedBox(height: AppSpacing.gutter),
        Row(
          children: [
            Switch.adaptive(
              key: const Key('product-quantity-list-switch'),
              value: productListVisible,
              activeThumbColor: AppColors.statusTabActive,
              inactiveThumbColor: colorScheme.onSurfaceVariant,
              inactiveTrackColor: colorScheme.outline,
              onChanged: (bool value) async {
                ref.read(productQuantityListVisibleProvider.notifier).state =
                    value;
                final ProductQuantityListPreferenceService service = ref.read(
                  productQuantityListPreferenceServiceProvider,
                );
                await service.save(value);
              },
            ),
            const SizedBox(width: AppSpacing.unit),
            Text(
              'Product & Quantity list',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OrderTitleNumberPicker extends ConsumerWidget {
  const _OrderTitleNumberPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final OrderTitleNumberSource selected = ref.watch(
      orderTitleNumberSourceProvider,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order title number',
          style: AppTextStyles.bodyMd.copyWith(color: colorScheme.onSurface),
        ),
        const SizedBox(height: AppSpacing.unit),
        Wrap(
          spacing: AppSpacing.unit,
          runSpacing: AppSpacing.unit,
          children: [
            for (final OrderTitleNumberSource source
                in OrderTitleNumberSource.values)
              ChoiceChip(
                key: Key('order-title-number-${source.name}'),
                label: Text(
                  source == OrderTitleNumberSource.displayNumber
                      ? 'Display number'
                      : 'KOT number',
                ),
                selected: selected == source,
                onSelected: (bool isSelected) async {
                  if (!isSelected) {
                    return;
                  }
                  ref.read(orderTitleNumberSourceProvider.notifier).state =
                      source;
                  await ref
                      .read(orderTitleNumberPreferenceServiceProvider)
                      .save(source);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _NotificationsSection extends ConsumerWidget {
  const _NotificationsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool enabled = ref.watch(announcementsEnabledProvider);
    final int pulseSeconds = ref.watch(orderUpdatePulseSecondsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Switch.adaptive(
              key: const Key('announcements-enabled-switch'),
              value: enabled,
              activeThumbColor: AppColors.statusTabActive,
              inactiveThumbColor: colorScheme.onSurfaceVariant,
              inactiveTrackColor: colorScheme.outline,
              onChanged: (bool value) async {
                ref.read(announcementsEnabledProvider.notifier).state = value;
                final AnnouncementPreferenceService service = ref.read(
                  announcementPreferenceServiceProvider,
                );
                await service.save(value);
              },
            ),
            const SizedBox(width: AppSpacing.unit),
            Text(
              'Announcements',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.gutter),
        _MinuteStepper(
          label: 'Highlight updated orders',
          value: pulseSeconds,
          unitLabel: 'sec',
          canDecrement:
              pulseSeconds > OrderUpdatePulsePreferenceService.minSeconds,
          canIncrement:
              pulseSeconds < OrderUpdatePulsePreferenceService.maxSeconds,
          decrementKey: const Key('pulse-stepper-dec'),
          incrementKey: const Key('pulse-stepper-inc'),
          valueKey: const Key('pulse-stepper-value'),
          onDecrement: () => _setPulseSeconds(ref, pulseSeconds - 1),
          onIncrement: () => _setPulseSeconds(ref, pulseSeconds + 1),
        ),
        const SizedBox(height: AppSpacing.gutter),
        OutlinedButton(
          key: const Key('test-announcement-button'),
          onPressed: () async {
            await ref.read(kdsTtsServiceProvider).speakNow(testAnnouncementLine);
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.onSurface,
            side: BorderSide(color: colorScheme.outline, width: 2),
            minimumSize: const Size.fromHeight(AppSpacing.touchTargetMin),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.defaultRadius),
            ),
          ),
          child: Text(
            'Test announcement',
            style: AppTextStyles.bodyMd.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.unit),
        Text(
          'Plays even when announcements are off.',
          style: AppTextStyles.bodyMd.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Future<void> _setPulseSeconds(WidgetRef ref, int seconds) async {
    final int clamped = seconds.clamp(
      OrderUpdatePulsePreferenceService.minSeconds,
      OrderUpdatePulsePreferenceService.maxSeconds,
    );
    ref.read(orderUpdatePulseSecondsProvider.notifier).state = clamped;
    await ref.read(orderUpdatePulsePreferenceServiceProvider).save(clamped);
  }
}

class _OrderTimingSection extends ConsumerWidget {
  const _OrderTimingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final UrgencySettingsController controller = ref.read(
      urgencySettingsProvider.notifier,
    );

    final int warningMinutes = ref.watch(
      urgencySettingsProvider.select(
        (UrgencySettings s) => s.warningMinutes,
      ),
    );
    final int criticalMinutes = ref.watch(
      urgencySettingsProvider.select(
        (UrgencySettings s) => s.criticalMinutes,
      ),
    );
    final Color warningColor = ref.watch(
      urgencySettingsProvider.select((UrgencySettings s) => s.warningColor),
    );
    final Color criticalColor = ref.watch(
      urgencySettingsProvider.select((UrgencySettings s) => s.criticalColor),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MinuteStepper(
          label: 'Warning after',
          value: warningMinutes,
          unitLabel: 'min',
          canDecrement: warningMinutes > UrgencySettings.minMinutes,
          canIncrement: warningMinutes < UrgencySettings.maxMinutes - 1,
          decrementKey: const Key('warning-stepper-dec'),
          incrementKey: const Key('warning-stepper-inc'),
          valueKey: const Key('warning-stepper-value'),
          onDecrement: () => controller.setWarningMinutes(warningMinutes - 1),
          onIncrement: () => controller.setWarningMinutes(warningMinutes + 1),
        ),
        const SizedBox(height: AppSpacing.gutter),
        _MinuteStepper(
          label: 'Critical after',
          value: criticalMinutes,
          unitLabel: 'min',
          canDecrement: criticalMinutes > warningMinutes + 1,
          canIncrement: criticalMinutes < UrgencySettings.maxMinutes,
          decrementKey: const Key('critical-stepper-dec'),
          incrementKey: const Key('critical-stepper-inc'),
          valueKey: const Key('critical-stepper-value'),
          onDecrement: () => controller.setCriticalMinutes(criticalMinutes - 1),
          onIncrement: () => controller.setCriticalMinutes(criticalMinutes + 1),
        ),
        const SizedBox(height: AppSpacing.gutter),
        Text(
          'Warning color',
          style: AppTextStyles.bodyMd.copyWith(color: colorScheme.onSurface),
        ),
        const SizedBox(height: AppSpacing.unit),
        _ColorSwatchRow(
          colors: UrgencyColorPresets.warningColorPresets,
          selected: warningColor,
          swatchKeyPrefix: 'warning-swatch',
          onSelected: controller.setWarningColor,
        ),
        const SizedBox(height: AppSpacing.gutter),
        Text(
          'Critical color',
          style: AppTextStyles.bodyMd.copyWith(color: colorScheme.onSurface),
        ),
        const SizedBox(height: AppSpacing.unit),
        _ColorSwatchRow(
          colors: UrgencyColorPresets.criticalColorPresets,
          selected: criticalColor,
          swatchKeyPrefix: 'critical-swatch',
          onSelected: controller.setCriticalColor,
        ),
        const SizedBox(height: AppSpacing.gutter),
        const _CancelledDisplayDurationPicker(),
        const SizedBox(height: AppSpacing.gutter),
        OutlinedButton(
          key: const Key('order-timing-reset'),
          onPressed: () => _confirmReset(context, ref),
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.onSurface,
            side: BorderSide(color: colorScheme.outline, width: 2),
            minimumSize: const Size.fromHeight(AppSpacing.touchTargetMin),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.defaultRadius),
            ),
          ),
          child: Text(
            'Reset to defaults',
            style: AppTextStyles.bodyMd.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final ColorScheme dialogColors = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: dialogColors.surfaceContainerHigh,
          title: Text(
            'Reset order timing?',
            style: AppTextStyles.headlineMd.copyWith(
              color: dialogColors.onSurface,
            ),
          ),
          content: Text(
            'Warning and critical thresholds and colors will return to defaults.',
            style: AppTextStyles.bodyMd.copyWith(
              color: dialogColors.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: AppTextStyles.bodyMd.copyWith(
                  color: dialogColors.onSurfaceVariant,
                ),
              ),
            ),
            TextButton(
              key: const Key('order-timing-reset-confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Reset',
                style: AppTextStyles.bodyMd.copyWith(
                  color: dialogColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }
    await ref.read(urgencySettingsProvider.notifier).resetToDefaults();
  }
}

class _CancelledDisplayDurationPicker extends ConsumerWidget {
  const _CancelledDisplayDurationPicker();

  static String _labelFor(int seconds) {
    return switch (seconds) {
      15 => '15 sec',
      30 => '30 sec',
      60 => '1 min',
      120 => '2 min',
      _ => '$seconds sec',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final int selected = ref.watch(cancelledDisplaySecondsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Show cancelled on Cooking',
          style: AppTextStyles.bodyMd.copyWith(color: colorScheme.onSurface),
        ),
        const SizedBox(height: AppSpacing.unit),
        Wrap(
          spacing: AppSpacing.unit,
          runSpacing: AppSpacing.unit,
          children: [
            for (final int seconds
                in KdsTiming.cancelledCookingDisplayOptionsSeconds)
              ChoiceChip(
                key: Key('cancelled-display-$seconds'),
                label: Text(_labelFor(seconds)),
                selected: selected == seconds,
                onSelected: (bool isSelected) async {
                  if (!isSelected) {
                    return;
                  }
                  ref.read(cancelledDisplaySecondsProvider.notifier).state =
                      seconds;
                  await ref
                      .read(cancelledDisplayPreferenceServiceProvider)
                      .save(seconds);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _MinuteStepper extends StatelessWidget {
  const _MinuteStepper({
    required this.label,
    required this.value,
    required this.unitLabel,
    required this.canDecrement,
    required this.canIncrement,
    required this.onDecrement,
    required this.onIncrement,
    required this.decrementKey,
    required this.incrementKey,
    required this.valueKey,
  });

  final String label;
  final int value;
  final String unitLabel;
  final bool canDecrement;
  final bool canIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final Key decrementKey;
  final Key incrementKey;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMd.copyWith(color: colorScheme.onSurface),
        ),
        const SizedBox(height: AppSpacing.unit),
        Row(
          children: [
            IconButton(
              key: decrementKey,
              onPressed: canDecrement ? onDecrement : null,
              icon: const Icon(Icons.remove),
              style: IconButton.styleFrom(
                minimumSize: const Size.square(AppSpacing.touchTargetMin),
              ),
            ),
            Expanded(
              child: Text(
                key: valueKey,
                '$value $unitLabel',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyLg.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              key: incrementKey,
              onPressed: canIncrement ? onIncrement : null,
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(
                minimumSize: const Size.square(AppSpacing.touchTargetMin),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ColorSwatchRow extends StatelessWidget {
  const _ColorSwatchRow({
    required this.colors,
    required this.selected,
    required this.swatchKeyPrefix,
    required this.onSelected,
  });

  final List<Color> colors;
  final Color selected;
  final String swatchKeyPrefix;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: AppSpacing.unit,
      runSpacing: AppSpacing.unit,
      children: [
        for (int i = 0; i < colors.length; i++)
          _ColorSwatch(
            key: Key('$swatchKeyPrefix-$i'),
            color: colors[i],
            selected: colors[i].toARGB32() == selected.toARGB32(),
            borderColor: colorScheme.onSurface,
            onTap: () => onSelected(colors[i]),
          ),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    super.key,
    required this.color,
    required this.selected,
    required this.borderColor,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: AppSpacing.touchTargetMin,
          height: AppSpacing.touchTargetMin,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: selected
                  ? Border.all(color: borderColor, width: AppRadii.md)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
