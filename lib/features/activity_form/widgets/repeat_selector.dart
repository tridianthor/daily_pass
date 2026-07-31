import 'package:flutter/material.dart';
import '../../../models/repeat_type.dart';
import '../../../core/constants/app_strings.dart';

class RepeatSelector extends StatelessWidget {
  final RepeatType value;
  final ValueChanged<RepeatType> onChanged;

  const RepeatSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

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
      ],
    );
  }
}
