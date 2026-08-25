import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../components/alarm_sound_picker.dart';
import '../models/alarm_sound.dart';
import '../models/interval_timer.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class EditIntervalTimerScreen extends StatefulWidget {
  const EditIntervalTimerScreen({
    super.key,
    required this.timer,
    required this.isNew,
  });

  final IntervalTimer timer;
  final bool isNew;

  @override
  State<EditIntervalTimerScreen> createState() =>
      _EditIntervalTimerScreenState();
}

class _EditIntervalTimerScreenState extends State<EditIntervalTimerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _databaseService = DatabaseService();

  late DateTime _startTime;
  late DateTime _endTime;
  late int _intervalValue;
  late IntervalType _intervalType;
  late AlarmSound _alarmSound;

  @override
  void initState() {
    super.initState();
    _nameController.text =
        widget.timer.name == 'New Interval Timer' ? '' : widget.timer.name;
    _startTime = widget.timer.startTime;
    _endTime = widget.timer.endTime;
    _intervalValue = widget.timer.intervalValue;
    _intervalType = widget.timer.intervalType;
    _alarmSound = widget.timer.alarmSound;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime),
    );

    if (pickedTime != null) {
      setState(() {
        _startTime = DateTime(
          _startTime.year,
          _startTime.month,
          _startTime.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        // If end time is before start time, adjust it
        if (_endTime.isBefore(_startTime)) {
          _endTime = _startTime.add(const Duration(hours: 1));
        }
      });
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endTime),
    );

    if (pickedTime != null) {
      setState(() {
        _endTime = DateTime(
          _endTime.year,
          _endTime.month,
          _endTime.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        // If end time is before start time, adjust it
        if (_endTime.isBefore(_startTime)) {
          _endTime = _startTime.add(const Duration(hours: 1));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'End time must be after start time. Adjusted automatically.',
              ),
            ),
          );
        }
      });
    }
  }

  Future<void> _saveTimer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final finalName =
        _nameController.text.trim().isEmpty
            ? 'New Interval Timer'
            : _nameController.text.trim();

    final updatedTimer = IntervalTimer(
      id: widget.timer.id,
      name: finalName,
      startTime: _startTime,
      endTime: _endTime,
      intervalValue: _intervalValue,
      intervalType: _intervalType,
      isActive: false,
      alarmSoundName: _alarmSound.name,
      createdAt: widget.timer.createdAt,
      updatedAt: DateTime.now(),
    );

    if (widget.isNew) {
      await _databaseService.createIntervalTimer(updatedTimer);
    } else {
      await _databaseService.updateIntervalTimer(updatedTimer);
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _selectAlarmSound() async {
    final choice = await showAlarmSoundPicker(
      context,
      selected: _alarmSound,
      title: 'Select Alarm Sound',
    );
    if (choice?.sound != null) {
      setState(() => _alarmSound = choice!.sound!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final timeFormat = DateFormat('h:mm a');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            CupertinoIcons.chevron_back,
            color: colorScheme.onSurface,
            size: 22,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isNew ? 'New Interval Timer' : 'Edit Interval Timer',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          children: [
            Text(
              'Timer Name',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.cardBackground(isDark: isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.separator(isDark: isDark),
                  width: 0.8,
                ),
              ),
              child: TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'New Interval Timer',
                  filled: false,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionHeader('Time Range', textTheme),
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.cardBackground(isDark: isDark),
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                border: Border.all(
                  color: AppTheme.separator(isDark: isDark),
                  width: 0.8,
                ),
              ),
              child: Material(
                // Gives the ListTiles a Material below the painted background so
                // their ink splashes stay visible.
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        'Start Time',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        timeFormat.format(_startTime),
                        style: textTheme.bodySmall,
                      ),
                      trailing: Icon(
                        CupertinoIcons.clock,
                        color: colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      onTap: () {
                        unawaited(HapticFeedback.selectionClick());
                        _selectStartTime();
                      },
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 4,
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: AppTheme.separator(isDark: isDark),
                    ),
                    ListTile(
                      title: Text(
                        'End Time',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        timeFormat.format(_endTime),
                        style: textTheme.bodySmall,
                      ),
                      trailing: Icon(
                        CupertinoIcons.clock,
                        color: colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      onTap: () {
                        unawaited(HapticFeedback.selectionClick());
                        _selectEndTime();
                      },
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionHeader('Interval Settings', textTheme),
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.cardBackground(isDark: isDark),
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                border: Border.all(
                  color: AppTheme.separator(isDark: isDark),
                  width: 0.8,
                ),
              ),
              child: Material(
                // Gives the ListTiles a Material below the painted background so
                // their ink splashes stay visible.
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        'Interval Type',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        _intervalType.displayName,
                        style: textTheme.bodySmall,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 4,
                      ),
                      trailing: DropdownButton<IntervalType>(
                        value: _intervalType,
                        onChanged: (IntervalType? newValue) {
                          if (newValue != null) {
                            unawaited(HapticFeedback.selectionClick());
                            setState(() {
                              _intervalType = newValue;
                            });
                          }
                        },
                        items:
                            IntervalType.values.map((IntervalType type) {
                              return DropdownMenuItem<IntervalType>(
                                value: type,
                                child: Text(type.displayName),
                              );
                            }).toList(),
                        underline: Container(),
                        icon: Icon(
                          CupertinoIcons.chevron_down,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: AppTheme.separator(isDark: isDark),
                    ),
                    ListTile(
                      title: Text(
                        'Interval Value',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '$_intervalValue ${_intervalType.unitLabel(_intervalValue)}',
                        style: textTheme.bodySmall,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 4,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(CupertinoIcons.minus, size: 16),
                            onPressed:
                                _intervalValue > 1
                                    ? () {
                                      unawaited(
                                        HapticFeedback.selectionClick(),
                                      );
                                      setState(() => _intervalValue--);
                                    }
                                    : null,
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(6),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$_intervalValue',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              CupertinoIcons.plus,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                            onPressed: () {
                              unawaited(HapticFeedback.selectionClick());
                              setState(() => _intervalValue++);
                            },
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(6),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: AppTheme.separator(isDark: isDark),
                    ),
                    ListTile(
                      title: Text(
                        'Alarm Sound',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        _alarmSound.displayName,
                        style: textTheme.bodySmall,
                      ),
                      trailing: Icon(
                        CupertinoIcons.music_note,
                        color: colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      onTap: () {
                        unawaited(HapticFeedback.selectionClick());
                        _selectAlarmSound();
                      },
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionHeader('Preview', textTheme),
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.cardBackground(isDark: isDark),
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                border: Border.all(
                  color: AppTheme.separator(isDark: isDark),
                  width: 0.8,
                ),
              ),
              child: Material(
                // Gives the ListTiles a Material below the painted background so
                // their ink splashes stay visible.
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          CupertinoIcons.info_circle,
                          color: colorScheme.primary,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        'Summary',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Alarms will sound $_intervalSummary between ${timeFormat.format(_startTime)} and ${timeFormat.format(_endTime)}',
                        style: textTheme.bodySmall,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: AppTheme.separator(isDark: isDark),
                    ),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.iosBlue.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.bell_fill,
                          color: AppTheme.iosBlue,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        'Total Alarms',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '$_totalAlarms alarms will be triggered',
                        style: textTheme.bodySmall,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  _saveTimer();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save Interval Timer',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, TextTheme textTheme) {
    return Text(
      title,
      style: textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    );
  }

  /// 'every hour', 'every 30 minutes', … for the summary sentence.
  String get _intervalSummary =>
      _intervalType.everyLabel(_intervalValue).toLowerCase();

  int get _totalAlarms =>
      IntervalTimer(
        name: '',
        startTime: _startTime,
        endTime: _endTime,
        intervalValue: _intervalValue,
        intervalType: _intervalType,
      ).totalAlarms;
}
