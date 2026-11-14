import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../components/alarm_sound_picker.dart';
import '../models/alarm_sound.dart';
import '../models/interval_timer.dart';
import '../services/database_service.dart';
// Gene - Nov, 14, 2026: Added IntervalSessionService import to refresh running/armed sessions when edits are saved.
import '../services/interval_session_service.dart';
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
  // Gene - Nov, 8, 2026: Added _isPointInTime and _activeDays state for Alert by Time and day-of-week recurrence editing.
  late bool _isPointInTime;
  late List<int> _activeDays;

  // @override
  // void initState() {
  //   super.initState();
  //   _nameController.text =
  //       widget.timer.name == 'New Interval Timer' ? '' : widget.timer.name;
  //   _startTime = widget.timer.startTime;
  //   _endTime = widget.timer.endTime;
  //   _intervalValue = widget.timer.intervalValue;
  //   _intervalType = widget.timer.intervalType;
  //   _alarmSound = widget.timer.alarmSound;
  // }
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
    _isPointInTime = widget.timer.isPointInTime;
    _activeDays = List<int>.from(widget.timer.activeDays);
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

  // Gene - Nov, 8, 2026: Save isPointInTime, activeDays, and preserve existing isActive flag.
  // Future<void> _saveTimer() async {
  //   if (!_formKey.currentState!.validate()) {
  //     return;
  //   }
  //
  //   final finalName =
  //       _nameController.text.trim().isEmpty
  //           ? 'New Interval Timer'
  //           : _nameController.text.trim();
  //
  //   final updatedTimer = IntervalTimer(
  //     id: widget.timer.id,
  //     name: finalName,
  //     startTime: _startTime,
  //     endTime: _endTime,
  //     intervalValue: _intervalValue,
  //     intervalType: _intervalType,
  //     isActive: false,
  //     alarmSoundName: _alarmSound.name,
  //     createdAt: widget.timer.createdAt,
  //     updatedAt: DateTime.now(),
  //   );
  //
  //   if (widget.isNew) {
  //     await _databaseService.createIntervalTimer(updatedTimer);
  //   } else {
  //     await _databaseService.updateIntervalTimer(updatedTimer);
  //   }
  //
  //   if (mounted) {
  //     Navigator.pop(context, true);
  //   }
  // }
  Future<void> _saveTimer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final defaultName =
        _isPointInTime ? 'Time Alert' : 'New Interval Timer';
    final finalName =
        _nameController.text.trim().isEmpty
            ? defaultName
            : _nameController.text.trim();

    final sortedDays = _activeDays.toSet().toList()..sort();
    final updatedTimer = IntervalTimer(
      id: widget.timer.id,
      name: finalName,
      startTime: _startTime,
      endTime: _isPointInTime ? _startTime : _endTime,
      intervalValue: _intervalValue,
      intervalType: _intervalType,
      isActive: widget.timer.isActive,
      alarmSoundName: _alarmSound.name,
      createdAt: widget.timer.createdAt,
      updatedAt: DateTime.now(),
      isPointInTime: _isPointInTime,
      activeDays: sortedDays,
    );

    // Gene - Nov, 14, 2026: Refresh IntervalSessionService if editing an armed or active interval timer so schedule & OS alarms update immediately, and add tooltips on icon controls.
    // if (widget.isNew) {
    //   await _databaseService.createIntervalTimer(updatedTimer);
    // } else {
    //   await _databaseService.updateIntervalTimer(updatedTimer);
    // }
    if (widget.isNew) {
      await _databaseService.createIntervalTimer(updatedTimer);
    } else {
      await _databaseService.updateIntervalTimer(updatedTimer);
      if (updatedTimer.isActive ||
          IntervalSessionService().active.value?.timer.id == updatedTimer.id) {
        IntervalSessionService().refreshIfActive(updatedTimer);
      }
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
        // Gene - Nov, 14, 2026: Add Back tooltip on navigation IconButton for screen reader clarity.
        // leading: IconButton(
        //   icon: Icon(
        //     CupertinoIcons.chevron_back,
        //     color: colorScheme.onSurface,
        //     size: 22,
        //   ),
        //   onPressed: () => Navigator.pop(context),
        // ),
        leading: IconButton(
          tooltip: 'Back',
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
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 14,
              bottom: 32,
            ),
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

              // Gene - Nov, 8, 2026: Added Alert Mode Segmented Control (Periodic Interval vs. Alert at Time), quick time presets, and Repeat Days recurrence selector.
              // _buildSectionHeader('Time Range', textTheme),
              // const SizedBox(height: 10),
              // DecoratedBox(
              //   decoration: BoxDecoration(
              //     color: AppTheme.cardBackground(isDark: isDark),
              //     borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              //     border: Border.all(
              //       color: AppTheme.separator(isDark: isDark),
              //       width: 0.8,
              //     ),
              //   ),
              //   child: Material(
              //     // Gives the ListTiles a Material below the painted background so
              //     // their ink splashes stay visible.
              //     type: MaterialType.transparency,
              //     child: Column(
              //       children: [
              //         ListTile(
              //           title: Text(
              //             'Start Time',
              //             style: textTheme.titleSmall?.copyWith(
              //               fontWeight: FontWeight.w600,
              //             ),
              //           ),
              //           subtitle: Text(
              //             timeFormat.format(_startTime),
              //             style: textTheme.bodySmall,
              //           ),
              //           trailing: Icon(
              //             CupertinoIcons.clock,
              //             color: colorScheme.onSurfaceVariant,
              //             size: 20,
              //           ),
              //           onTap: () {
              //             unawaited(HapticFeedback.selectionClick());
              //             _selectStartTime();
              //           },
              //           contentPadding: const EdgeInsets.symmetric(
              //             horizontal: 18,
              //             vertical: 4,
              //           ),
              //         ),
              //         Divider(
              //           height: 1,
              //           color: AppTheme.separator(isDark: isDark),
              //         ),
              //         ListTile(
              //           title: Text(
              //             'End Time',
              //             style: textTheme.titleSmall?.copyWith(
              //               fontWeight: FontWeight.w600,
              //             ),
              //           ),
              //           subtitle: Text(
              //             timeFormat.format(_endTime),
              //             style: textTheme.bodySmall,
              //           ),
              //           trailing: Icon(
              //             CupertinoIcons.clock,
              //             color: colorScheme.onSurfaceVariant,
              //             size: 20,
              //           ),
              //           onTap: () {
              //             unawaited(HapticFeedback.selectionClick());
              //             _selectEndTime();
              //           },
              //           contentPadding: const EdgeInsets.symmetric(
              //             horizontal: 18,
              //             vertical: 4,
              //           ),
              //         ),
              //       ],
              //     ),
              //   ),
              // ),
              // const SizedBox(height: 24),
              _buildSectionHeader('Alert Mode', textTheme),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Periodic Interval'),
                      icon: Icon(CupertinoIcons.repeat, size: 16),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Alert at Time'),
                      icon: Icon(CupertinoIcons.alarm_fill, size: 16),
                    ),
                  ],
                  selected: {_isPointInTime},
                  onSelectionChanged: (selection) {
                    unawaited(HapticFeedback.selectionClick());
                    setState(() {
                      _isPointInTime = selection.first;
                      if (_isPointInTime) {
                        _endTime = _startTime;
                      } else if (!_endTime.isAfter(_startTime)) {
                        _endTime = _startTime.add(const Duration(hours: 8));
                      }
                    });
                  },
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    selectedBackgroundColor: colorScheme.primary.withValues(
                      alpha: 0.18,
                    ),
                    selectedForegroundColor: colorScheme.primary,
                    side: BorderSide(
                      color: AppTheme.separator(isDark: isDark),
                      width: 0.8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _buildSectionHeader(
                _isPointInTime ? 'Alert Time' : 'Time Range',
                textTheme,
              ),
              const SizedBox(height: 8),
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
                  type: MaterialType.transparency,
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(
                          _isPointInTime ? 'Alert Time' : 'Start Time',
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
                      if (_isPointInTime) ...[
                        Divider(
                          height: 1,
                          color: AppTheme.separator(isDark: isDark),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildQuickTimeChip(
                                label: '+15m',
                                onTap: () => _setStartTimeOffset(
                                  const Duration(minutes: 15),
                                ),
                                colorScheme: colorScheme,
                              ),
                              _buildQuickTimeChip(
                                label: '+30m',
                                onTap: () => _setStartTimeOffset(
                                  const Duration(minutes: 30),
                                ),
                                colorScheme: colorScheme,
                              ),
                              _buildQuickTimeChip(
                                label: '+1h',
                                onTap: () => _setStartTimeOffset(
                                  const Duration(hours: 1),
                                ),
                                colorScheme: colorScheme,
                              ),
                              _buildQuickTimeChip(
                                label: '9:00 AM',
                                onTap: () => _setFixedClockTime(9, 0),
                                colorScheme: colorScheme,
                              ),
                              _buildQuickTimeChip(
                                label: '12:00 PM',
                                onTap: () => _setFixedClockTime(12, 0),
                                colorScheme: colorScheme,
                              ),
                              _buildQuickTimeChip(
                                label: '6:00 PM',
                                onTap: () => _setFixedClockTime(18, 0),
                                colorScheme: colorScheme,
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Gene - Nov, 8, 2026: Conditionally display Interval Type/Value rows only in Periodic mode, while keeping Alarm Sound and placing Repeat Days below Interval Settings so Interval Settings stays above the fold.
              // _buildSectionHeader('Interval Settings', textTheme),
              // const SizedBox(height: 10),
              // DecoratedBox(
              //   decoration: BoxDecoration(
              //     color: AppTheme.cardBackground(isDark: isDark),
              //     borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              //     border: Border.all(
              //       color: AppTheme.separator(isDark: isDark),
              //       width: 0.8,
              //     ),
              //   ),
              //   child: Material(
              //     type: MaterialType.transparency,
              //     child: Column(
              //       children: [ ... ],
              //     ),
              //   ),
              // ),
              _buildSectionHeader(
                _isPointInTime ? 'Sound Settings' : 'Interval Settings',
                textTheme,
              ),
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
                      if (!_isPointInTime) ...[
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
                          // Gene - Nov, 14, 2026: Add tooltips and >= 44x44 minimum tap targets on interval stepper buttons.
                          // trailing: Row(
                          //   mainAxisSize: MainAxisSize.min,
                          //   children: [
                          //     IconButton(
                          //       icon: const Icon(
                          //         CupertinoIcons.minus,
                          //         size: 16,
                          //       ),
                          //       onPressed:
                          //           _intervalValue > 1
                          //               ? () {
                          //                 unawaited(
                          //                   HapticFeedback.selectionClick(),
                          //                 );
                          //                 setState(() => _intervalValue--);
                          //               }
                          //               : null,
                          //       constraints: const BoxConstraints(),
                          //       padding: const EdgeInsets.all(6),
                          //     ),
                          //     const SizedBox(width: 8),
                          //     Text(
                          //       '$_intervalValue',
                          //       style: textTheme.titleMedium?.copyWith(
                          //         fontWeight: FontWeight.w700,
                          //       ),
                          //     ),
                          //     const SizedBox(width: 8),
                          //     IconButton(
                          //       icon: Icon(
                          //         CupertinoIcons.plus,
                          //         size: 16,
                          //         color: colorScheme.primary,
                          //       ),
                          //       onPressed: () {
                          //         unawaited(HapticFeedback.selectionClick());
                          //         setState(() => _intervalValue++);
                          //       },
                          //       constraints: const BoxConstraints(),
                          //       padding: const EdgeInsets.all(6),
                          //     ),
                          //   ],
                          // ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Decrease interval',
                                icon: const Icon(
                                  CupertinoIcons.minus,
                                  size: 16,
                                ),
                                onPressed:
                                    _intervalValue > 1
                                        ? () {
                                          unawaited(
                                            HapticFeedback.selectionClick(),
                                          );
                                          setState(() => _intervalValue--);
                                        }
                                        : null,
                                constraints: const BoxConstraints(
                                  minWidth: 44,
                                  minHeight: 44,
                                ),
                                padding: const EdgeInsets.all(8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$_intervalValue',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                tooltip: 'Increase interval',
                                icon: Icon(
                                  CupertinoIcons.plus,
                                  size: 16,
                                  color: colorScheme.primary,
                                ),
                                onPressed: () {
                                  unawaited(HapticFeedback.selectionClick());
                                  setState(() => _intervalValue++);
                                },
                                constraints: const BoxConstraints(
                                  minWidth: 44,
                                  minHeight: 44,
                                ),
                                padding: const EdgeInsets.all(8),
                              ),
                            ],
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: AppTheme.separator(isDark: isDark),
                        ),
                      ],
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

              _buildSectionHeader('Repeat Days', textTheme),
              const SizedBox(height: 10),
              _buildRecurrenceCard(isDark, colorScheme, textTheme),
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
                          _isPointInTime
                              ? 'Alert will sound at ${timeFormat.format(_startTime)} ($_recurrenceSummary)'
                              : 'Alarms will sound $_intervalSummary between ${timeFormat.format(_startTime)} and ${timeFormat.format(_endTime)} ($_recurrenceSummary)',
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
                          '$_totalAlarms ${_totalAlarms == 1 ? 'alarm' : 'alarms'} will be triggered',
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

  // Gene - Nov, 8, 2026: Added helper methods for quick clock-time presets and day-of-week recurrence selection.
  void _setStartTimeOffset(Duration offset) {
    unawaited(HapticFeedback.selectionClick());
    final target = DateTime.now().add(offset);
    setState(() {
      _startTime = DateTime(
        target.year,
        target.month,
        target.day,
        target.hour,
        target.minute,
      );
      if (_isPointInTime || _endTime.isBefore(_startTime)) {
        _endTime = _startTime;
      }
    });
  }

  void _setFixedClockTime(int hour, int minute) {
    unawaited(HapticFeedback.selectionClick());
    final now = DateTime.now();
    setState(() {
      _startTime = DateTime(now.year, now.month, now.day, hour, minute);
      if (_isPointInTime || _endTime.isBefore(_startTime)) {
        _endTime = _startTime;
      }
    });
  }

  Widget _buildQuickTimeChip({
    required String label,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: colorScheme.primary,
        ),
      ),
      backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
    );
  }

  Widget _buildRecurrenceCard(
    bool isDark,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    const days = <(int, String)>[
      (DateTime.monday, 'M'),
      (DateTime.tuesday, 'T'),
      (DateTime.wednesday, 'W'),
      (DateTime.thursday, 'T'),
      (DateTime.friday, 'F'),
      (DateTime.saturday, 'S'),
      (DateTime.sunday, 'S'),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground(isDark: isDark),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(
          color: AppTheme.separator(isDark: isDark),
          width: 0.8,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final (weekday, shortLabel) in days)
                  GestureDetector(
                    key: Key('weekday-chip-$weekday'),
                    onTap: () {
                      unawaited(HapticFeedback.selectionClick());
                      setState(() {
                        if (_activeDays.contains(weekday)) {
                          _activeDays.remove(weekday);
                        } else {
                          _activeDays.add(weekday);
                        }
                      });
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color:
                            _activeDays.contains(weekday)
                                ? colorScheme.primary
                                : colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        shortLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color:
                              _activeDays.contains(weekday)
                                  ? Colors.white
                                  : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildQuickTimeChip(
                  label: 'Every Day',
                  onTap: () {
                    unawaited(HapticFeedback.selectionClick());
                    setState(() {
                      _activeDays = <int>[1, 2, 3, 4, 5, 6, 7];
                    });
                  },
                  colorScheme: colorScheme,
                ),
                _buildQuickTimeChip(
                  label: 'Weekdays',
                  onTap: () {
                    unawaited(HapticFeedback.selectionClick());
                    setState(() {
                      _activeDays = <int>[1, 2, 3, 4, 5];
                    });
                  },
                  colorScheme: colorScheme,
                ),
                _buildQuickTimeChip(
                  label: 'Weekends',
                  onTap: () {
                    unawaited(HapticFeedback.selectionClick());
                    setState(() {
                      _activeDays = <int>[6, 7];
                    });
                  },
                  colorScheme: colorScheme,
                ),
                _buildQuickTimeChip(
                  label: 'One-time',
                  onTap: () {
                    unawaited(HapticFeedback.selectionClick());
                    setState(() {
                      _activeDays = <int>[];
                    });
                  },
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _recurrenceSummary =>
      IntervalTimer(
        name: '',
        startTime: _startTime,
        endTime: _isPointInTime ? _startTime : _endTime,
        intervalValue: _intervalValue,
        intervalType: _intervalType,
        isPointInTime: _isPointInTime,
        activeDays: _activeDays,
      ).recurrenceLabel;

  /// 'every hour', 'every 30 minutes', … for the summary sentence.
  String get _intervalSummary =>
      _intervalType.everyLabel(_intervalValue).toLowerCase();

  // int get _totalAlarms =>
  //     IntervalTimer(
  //       name: '',
  //       startTime: _startTime,
  //       endTime: _endTime,
  //       intervalValue: _intervalValue,
  //       intervalType: _intervalType,
  //     ).totalAlarms;
  int get _totalAlarms =>
      IntervalTimer(
        name: '',
        startTime: _startTime,
        endTime: _isPointInTime ? _startTime : _endTime,
        intervalValue: _intervalValue,
        intervalType: _intervalType,
        isPointInTime: _isPointInTime,
        activeDays: _activeDays,
      ).totalAlarms;
}
