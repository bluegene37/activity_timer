import 'package:flutter/material.dart';
import '../models/activity_timer.dart';
import '../models/alarm_sound.dart';
import '../models/interval_phase.dart';

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

    int totalSeconds = widget.timer.durationInSeconds;
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
    showDialog(
      context: context,
      builder: (BuildContext context) {
        int hours = _hours;
        int minutes = _minutes;
        int seconds = _seconds;

        return AlertDialog(
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
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
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
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
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
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
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
                      style: Theme.of(context).textTheme.titleMedium,
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
              child: const Text('Set'),
            ),
          ],
        );
      },
    );
  }

  void _selectAlarmSound() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.isNew ? 'Add Timer' : 'Edit Timer'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _saveTimer,
            child: Text(
              'SAVE',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Phase Selector
            Text('Interval Phase', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Row(
                children: IntervalPhase.values.map((phase) {
                  final isSelected = _phase == phase;
                  return Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _phase = phase),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? phase.defaultColor.withValues(alpha: 0.18)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(color: phase.defaultColor, width: 1.5)
                              : null,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              phase.icon,
                              size: 20,
                              color: isSelected ? phase.defaultColor : colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              phase.displayName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
            const SizedBox(height: 28),

            Text('Timer Name', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'e.g. Sprint, Rest, Work Block',
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            const SizedBox(height: 28),

            Text('Duration', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            InkWell(
              onTap: _showTimePickerDialog,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(),
                      style: textTheme.titleMedium,
                    ),
                    Icon(Icons.access_time, color: colorScheme.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text('Quick Presets', style: textTheme.titleSmall),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickDurationButton(15, colorScheme, textTheme),
                _buildQuickDurationButton(20, colorScheme, textTheme),
                _buildQuickDurationButton(30, colorScheme, textTheme),
                _buildQuickDurationButton(45, colorScheme, textTheme),
                _buildQuickDurationButton(60, colorScheme, textTheme),
                _buildQuickDurationButton(120, colorScheme, textTheme),
                _buildQuickDurationButton(300, colorScheme, textTheme),
                _buildQuickDurationButton(1500, colorScheme, textTheme),
              ],
            ),
            const SizedBox(height: 28),

            Text('Custom Alarm Sound', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectAlarmSound,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedAlarmSound != null ? _selectedAlarmSound!.displayName : 'Default App Sound',
                      style: textTheme.titleMedium,
                    ),
                    Icon(Icons.music_note, color: colorScheme.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            Text('Description (optional)', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'e.g. Burpees, Hydrate, Deep focus',
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            const SizedBox(height: 36),
            
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saveTimer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Save Timer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickDurationButton(int seconds, ColorScheme colorScheme, TextTheme textTheme) {
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
        setState(() {
          _hours = hours;
          _minutes = minutes;
          _seconds = remainingSeconds;
        });
      },
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(
        label,
        style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
      ),
    );
  }
}
