import 'package:flutter/material.dart';
import '../models/activity_timer.dart';
import '../components/for_ui_button.dart';
import '../components/for_ui_text_field.dart';
import '../theme/for_ui.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.timer.id.isEmpty ? 'Add Timer' : 'Edit Timer'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _saveTimer,
            child: Text(
              'SAVE',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ForUI.spacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ForUITextField(
              label: 'Timer Name',
              controller: _nameController,
              hint: 'Enter timer name',
            ),
            const SizedBox(height: ForUI.spacingLarge),

            Text('Duration', style: theme.textTheme.titleMedium),
            const SizedBox(height: ForUI.spacingSmall),
            InkWell(
              onTap: _showTimePickerDialog,
              borderRadius: BorderRadius.circular(ForUI.borderRadius),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(ForUI.borderRadius),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Duration: ${_formatDuration()}',
                      style: theme.textTheme.titleMedium,
                    ),
                    Icon(Icons.access_time, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),

            const SizedBox(height: ForUI.spacingLarge),

            Text('Quick Presets', style: theme.textTheme.titleMedium),
            const SizedBox(height: ForUI.spacingSmall),

            // Quick duration buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickDurationButton(15),
                _buildQuickDurationButton(30),
                _buildQuickDurationButton(45),
                _buildQuickDurationButton(60),
                _buildQuickDurationButton(120),
                _buildQuickDurationButton(300),
                _buildQuickDurationButton(600),
                _buildQuickDurationButton(1800),
                _buildQuickDurationButton(3600),
              ],
            ),

            const SizedBox(height: ForUI.spacingLarge),

            ForUITextField(
              label: 'Description (optional)',
              controller: _descriptionController,
              hint: 'e.g., Push-ups, Rest, Stretching',
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickDurationButton(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    String label;
    if (hours > 0) {
      label =
          '$hours:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    } else if (minutes > 0) {
      label = '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      label = '$seconds sec';
    }

    return ForUIButton(
      text: label,
      onPressed: () {
        setState(() {
          _hours = hours;
          _minutes = minutes;
          _seconds = remainingSeconds;
        });
      },
      isPrimary: false,
      isSmall: true,
    );
  }
}
