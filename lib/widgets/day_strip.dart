import 'package:flutter/material.dart';

import '../models/course.dart';
import 'theme.dart';

/// Five weekday columns; bar height shows that day's teaching hours.
class DayStrip extends StatelessWidget {
  const DayStrip({
    super.key,
    required this.minutes,
    required this.clashDays,
    required this.selected,
    required this.onSelect,
  });

  final List<int> minutes;
  final Set<int> clashDays;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final most = minutes.fold<int>(60, (a, b) => b > a ? b : a);
    return Row(
      children: [
        for (var i = 0; i < dayShort.length; i++)
          Expanded(
            child: _Day(
              label: dayShort[i],
              fill: minutes[i] / most,
              hours: minutes[i] / 60,
              clash: clashDays.contains(i),
              selected: selected == i,
              onTap: () => onSelect(i),
            ),
          ),
      ],
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({
    required this.label,
    required this.fill,
    required this.hours,
    required this.clash,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final double fill;
  final double hours;
  final bool clash;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hoursText =
        hours == 0 ? 'free' : '${hours.toStringAsFixed(hours % 1 == 0 ? 0 : 1)}h';
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $hoursText${clash ? ', has a clash' : ''}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: selected ? ink : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: selected ? ink : line),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
              child: Column(
                children: [
                  SizedBox(
                    height: 56,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        width: 10,
                        height: 4 + 52 * fill,
                        decoration: BoxDecoration(
                          color: clash
                              ? clashRed
                              : selected
                                  ? Colors.white
                                  : ink.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : ink,
                    ),
                  ),
                  Text(
                    hoursText,
                    style: TextStyle(
                      fontSize: 12,
                      fontFeatures: tabular,
                      color: selected ? Colors.white70 : slate,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
