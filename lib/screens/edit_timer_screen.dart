import 'package:flutter/material.dart';
import '../models/activity_timer.dart';
import '../theme/app_theme.dart';

class EditTimerScreen extends StatefulWidget {
  final ActivityTimer timer;

  const EditTimerScreen({super.key, required this.timer});

  @override
  State<EditTimerScreen> createState() => _EditTimerScreenState();
}

class _EditTimerScreenState extends State<EditTimerScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late int _hours;
  late int _minutes;
  late int _seconds;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.timer.name);
    _descriptionController = TextEditingController(
      text: widget.timer.description ?? '',
    );

    // Convert total seconds to hours, minutes, seconds
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
        title: Text(widget.timer.id.isEmpty ? 'Add Timer' : 'Edit Timer'),
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
            Text('Timer Name', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Enter timer name',
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            const SizedBox(height: 32),

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
            const SizedBox(height: 32),

            Text('Quick Presets', style: textTheme.titleSmall),
            const SizedBox(height: 12),

            // Quick duration buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickDurationButton(15, colorScheme, textTheme),
                _buildQuickDurationButton(30, colorScheme, textTheme),
                _buildQuickDurationButton(45, colorScheme, textTheme),
                _buildQuickDurationButton(60, colorScheme, textTheme),
                _buildQuickDurationButton(120, colorScheme, textTheme),
                _buildQuickDurationButton(300, colorScheme, textTheme),
                _buildQuickDurationButton(600, colorScheme, textTheme),
                _buildQuickDurationButton(1800, colorScheme, textTheme),
                _buildQuickDurationButton(3600, colorScheme, textTheme),
              ],
            ),
            const SizedBox(height: 32),

            Text('Description (optional)', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'e.g., Push-ups, Rest, Stretching',
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            const SizedBox(height: 40),
            
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
