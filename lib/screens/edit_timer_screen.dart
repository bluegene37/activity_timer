import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/activity_timer.dart';
import '../models/alarm_sound.dart';
import '../models/interval_phase.dart';
import '../theme/app_theme.dart';

class EditTimerScreen extends StatefulWidget {
  final ActivityTimer timer;
  final bool isNew;

  const EditTimerScreen({super.key, required this.timer, this.isNew = false});

  @override
  State<EditTimerScreen> createState() => _EditTimerScreenState();
}

class _EditTimerScreenState extends State<EditTimerScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late int _hours;
  late int _minutes;
  late int _seconds;
  late IntervalPhase _phase;
  AlarmSound? _selectedAlarmSound;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.timer.name);
    _descriptionController = TextEditingController(
      text: widget.timer.description ?? '',
    );
    _selectedAlarmSound = widget.timer.alarmSound;
    _phase = widget.timer.phase;

    final int totalSeconds = widget.timer.durationInSeconds;
    _hours = totalSeconds ~/ 3600;
    _minutes = (totalSeconds % 3600) ~/ 60;
    _seconds = totalSeconds % 60;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _formatDuration() {
    final parts = <String>[];

    if (_hours > 0) {
      parts.add('$_hours hr');
    }

    if (_minutes > 0 || (_hours > 0 && _seconds > 0)) {
      parts.add('$_minutes min');
    }

    if (_seconds > 0 || parts.isEmpty) {
      parts.add('$_seconds sec');
    }

    return parts.join(' ');
  }

  void _showTimePickerDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        int hours = _hours;
        int minutes = _minutes;
        int seconds = _seconds;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Set Duration'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SizedBox(
                height: 250,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text('Hours'),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                initialValue: hours,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                ),
                                items:
                                    List.generate(24, (index) => index)
                                        .map(
                                          (hour) => DropdownMenuItem<int>(
                                            value: hour,
                                            child: Text(hour.toString()),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => hours = value);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text('Minutes'),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                initialValue: minutes,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                ),
                                items:
                                    List.generate(60, (index) => index)
                                        .map(
                                          (minute) => DropdownMenuItem<int>(
                                            value: minute,
                                            child: Text(minute.toString()),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => minutes = value);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text('Seconds'),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                initialValue: seconds,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                ),
                                items:
                                    List.generate(60, (index) => index)
                                        .map(
                                          (second) => DropdownMenuItem<int>(
                                            value: second,
                                            child: Text(second.toString()),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => seconds = value);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Total: ${_formatTimeValue(hours)}:${_formatTimeValue(minutes)}:${_formatTimeValue(seconds)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _hours = hours;
                  _minutes = minutes;
                  _seconds = seconds;
                });
                Navigator.pop(context);
              },
              child: const Text('Set', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _selectAlarmSound() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Select Alarm Sound'),
        content: SizedBox(
          width: double.maxFinite,
          child: RadioGroup<AlarmSound?>(
            groupValue: _selectedAlarmSound,
            onChanged: (AlarmSound? value) {
              setState(() => _selectedAlarmSound = value);
              Navigator.pop(context);
            },
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: AlarmSound.values.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ListTile(
                    leading: const Radio<AlarmSound?>(value: null),
                    title: const Text('Use Default App Sound'),
                    onTap: () {
                      setState(() => _selectedAlarmSound = null);
                      Navigator.pop(context);
                    },
                  );
                }
                final sound = AlarmSound.values[index - 1];
                return ListTile(
                  leading: Radio<AlarmSound?>(value: sound),
                  title: Text(sound.displayName),
                  onTap: () {
                    setState(() => _selectedAlarmSound = sound);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  String _formatTimeValue(int value) {
    return value.toString().padLeft(2, '0');
  }

  void _saveTimer() {
    final totalSeconds = (_hours * 3600) + (_minutes * 60) + _seconds;
    if (totalSeconds <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Timer duration must be greater than 0 seconds'),
        ),
      );
      return;
    }

    final updatedTimer = widget.timer.copyWith(
      name: _nameController.text.isNotEmpty ? _nameController.text : 'Timer',
      durationInSeconds: totalSeconds,
      description:
          _descriptionController.text.isEmpty
              ? null
              : _descriptionController.text,
      alarmSoundName: _selectedAlarmSound?.name,
      phase: _phase,
    );

    Navigator.pop(context, updatedTimer);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_back, color: colorScheme.onSurface, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.isNew ? 'Add Timer' : 'Edit Timer', style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              unawaited(HapticFeedback.selectionClick());
              _saveTimer();
            },
            child: Text(
              'SAVE',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Phase Selector
            Text('Interval Phase', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: IntervalPhase.values.map((phase) {
                  final isSelected = _phase == phase;
                  return Expanded(
                    child: InkWell(
                      onTap: () {
                        unawaited(HapticFeedback.selectionClick());
                        setState(() => _phase = phase);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? phase.defaultColor.withValues(alpha: 0.18)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected
                              ? Border.all(color: phase.defaultColor, width: 1.2)
                              : null,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              phase.icon,
                              size: 18,
                              color: isSelected ? phase.defaultColor : colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              phase.displayName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                                color: isSelected ? phase.defaultColor : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 22),

            Text('Timer Name', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA),
                  width: 0.8,
                ),
              ),
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Sprint, Rest, Work Block',
                  filled: false,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 22),

            Text('Duration', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                unawaited(HapticFeedback.selectionClick());
                _showTimePickerDialog();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(),
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Icon(CupertinoIcons.clock, color: colorScheme.primary, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            Text('Quick Presets', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickDurationButton(15, colorScheme, textTheme, isDark),
                _buildQuickDurationButton(20, colorScheme, textTheme, isDark),
                _buildQuickDurationButton(30, colorScheme, textTheme, isDark),
                _buildQuickDurationButton(45, colorScheme, textTheme, isDark),
                _buildQuickDurationButton(60, colorScheme, textTheme, isDark),
                _buildQuickDurationButton(120, colorScheme, textTheme, isDark),
                _buildQuickDurationButton(300, colorScheme, textTheme, isDark),
                _buildQuickDurationButton(1500, colorScheme, textTheme, isDark),
              ],
            ),
            const SizedBox(height: 22),

            Text('Custom Alarm Sound', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                unawaited(HapticFeedback.selectionClick());
                _selectAlarmSound();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedAlarmSound != null ? _selectedAlarmSound!.displayName : 'Default App Sound',
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Icon(CupertinoIcons.music_note, color: colorScheme.primary, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),

            Text('Description (optional)', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA),
                  width: 0.8,
                ),
              ),
              child: TextField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'e.g. Burpees, Hydrate, Deep focus',
                  filled: false,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  unawaited(HapticFeedback.selectionClick());
                  _saveTimer();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Save Timer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickDurationButton(int seconds, ColorScheme colorScheme, TextTheme textTheme, bool isDark) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    String label;
    if (hours > 0) {
      label = '$hours:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    } else if (minutes > 0) {
      label = '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      label = '$seconds sec';
    }

    return OutlinedButton(
      onPressed: () {
        unawaited(HapticFeedback.selectionClick());
        setState(() {
          _hours = hours;
          _minutes = minutes;
          _seconds = remainingSeconds;
        });
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        side: BorderSide(
          color: isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA),
          width: 0.8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.pillRadius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      ),
      child: Text(
        label,
        style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

