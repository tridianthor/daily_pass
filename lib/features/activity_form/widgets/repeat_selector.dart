import 'package:flutter/material.dart';
import '../../../models/repeat_type.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_spacing.dart';
class RepeatSelector extends StatelessWidget {
  final RepeatType value;
  final ValueChanged<RepeatType> onChanged;
  final int? dayOfWeek;
  final ValueChanged<int?>? onDayOfWeekChanged;

  const RepeatSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.dayOfWeek,
    this.onDayOfWeekChanged,
  });

  static const _weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          AppStrings.repeat,
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<RepeatType>(
          value: value,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: RepeatType.values.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(type.displayName),
            );
          }).toList(),
          onChanged: (type) {
            if (type != null) onChanged(type);
          },
        ),
        if (value == RepeatType.weekly) ...[
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Repeat on',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: List.generate(7, (i) => ButtonSegment(
              value: i,
              label: Text(_weekdays[i]),
            )),
            selected: {dayOfWeek ?? 0},
            onSelectionChanged: (selected) {
              onDayOfWeekChanged?.call(selected.first);
            },
          ),
        ],
      ],
    );
  }
}
