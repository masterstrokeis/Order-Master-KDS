import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/station_model.dart';
import '../../../providers/providers.dart';

class StationSelector extends ConsumerWidget {
  const StationSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Station> stations = ref.watch(stationsProvider);
    final String? selected = ref.watch(selectedStationProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      decoration: BoxDecoration(
        color: AppColors.lightSidebar,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          dropdownColor: AppColors.lightSidebar,
          iconEnabledColor: Colors.white70,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          items: [
            for (final Station station in stations)
              DropdownMenuItem<String>(
                value: station.id,
                child: Text(station.name),
              ),
          ],
          onChanged: (String? value) {
            ref.read(selectedStationProvider.notifier).state = value;
          },
        ),
      ),
    );
  }
}
