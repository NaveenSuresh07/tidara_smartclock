import 'package:flutter/material.dart';
import '../../shared/widgets/liquid_glass_components.dart';

/// Shows a dialog prompting the user for a custom focus duration in minutes (1–180).
Future<int?> showCustomDurationDialog(
  BuildContext context, {
  required int initialMinutes,
}) async {
  final TextEditingController ctrl = TextEditingController(
    text: initialMinutes.clamp(1, 180).toString(),
  );

  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text(
        'Custom Focus Duration',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter any duration between 1 and 180 minutes (e.g. 25 for Pomodoro, 24 for Focus Interval):',
            style: TextStyle(fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              suffixText: 'minutes',
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
      actions: [
        GlassButton.secondary(
          label: 'Cancel',
          onPressed: () => Navigator.of(ctx).pop(null),
        ),
        GlassButton.primary(
          label: 'Set Duration',
          onPressed: () {
            final int? val = int.tryParse(ctrl.text.trim());
            if (val != null && val >= 1 && val <= 180) {
              Navigator.of(ctx).pop(val);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Please enter a valid duration between 1 and 180 minutes.',
                  ),
                ),
              );
            }
          },
        ),
      ],
    ),
  );
}
