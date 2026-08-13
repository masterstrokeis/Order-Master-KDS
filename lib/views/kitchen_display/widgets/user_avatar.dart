import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class UserAvatar extends ConsumerWidget {
  const UserAvatar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String initials = ref.watch(
      authControllerProvider.select((AuthState state) {
        final String? fromSession = state.session?.staff.initials;
        if (fromSession != null && fromSession.isNotEmpty) {
          return fromSession;
        }
        return _initialsFor(state.selectedStaffName);
      }),
    );

    return Material(
      color: Colors.grey.shade300,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        // TODO: wire avatar menu (logout / settings) when specified.
        onTap: () {},
        child: SizedBox(
          width: AppSpacing.touchTargetMin * 0.7,
          height: AppSpacing.touchTargetMin * 0.7,
          child: Center(
            child: Text(
              initials,
              style: const TextStyle(
                color: AppColors.lightOnSurface,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _initialsFor(String? staff) {
    if (staff == null || staff.trim().isEmpty) {
      return 'MC';
    }
    final List<String> parts = staff
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList();
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
