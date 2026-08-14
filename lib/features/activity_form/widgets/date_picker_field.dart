import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final bool allowClear;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const DatePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.allowClear = false,
    this.firstDate,
    this.lastDate,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final effectiveFirstDate = firstDate ?? today;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final initial = value != null && !value!.isBefore(effectiveFirstDate)
                      ? value!
                      : effectiveFirstDate;
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: effectiveFirstDate,
                    lastDate: lastDate ?? DateTime(2100),
                    selectableDayPredicate: (day) {
                      final normalizedDay = DateTime(day.year, day.month, day.day);
                      return !normalizedDay.isBefore(effectiveFirstDate);
                    },
                  );
                  if (picked != null) onChanged(picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          value != null
                              ? dateFormat.format(value!)
                              : 'Select date',
                          style: TextStyle(
                            color: value != null ? null : Colors.grey,
                          ),
                        ),
                      ),
                      const Icon(Icons.calendar_today, size: 20),
                    ],
                  ),
                ),
              ),
            ),
            if (allowClear && value != null)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => onChanged(today),
              ),
          ],
        ),
      ],
    );
  }
}
