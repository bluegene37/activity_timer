import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/interval_timer.dart';
import '../models/alarm_sound.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class EditIntervalTimerScreen extends StatefulWidget {
  final IntervalTimer timer;
  final bool isNew;

  const EditIntervalTimerScreen({
    super.key,
    required this.timer,
    required this.isNew,
  });

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
    _nameController.text = widget.timer.name == 'New Interval Timer' ? '' : widget.timer.name;
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

    final finalName = _nameController.text.trim().isEmpty 
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

  void _selectAlarmSound() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Select Alarm Sound'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: AlarmSound.values.length,
                itemBuilder: (context, index) {
                  final sound = AlarmSound.values[index];
                  return RadioListTile<AlarmSound>(
                    title: Text(sound.displayName),
                    value: sound,
                    groupValue: _alarmSound,
                    onChanged: (AlarmSound? value) {
                      if (value != null) {
                        setState(() {
                          _alarmSound = value;
                        });
                        Navigator.pop(context);
                      }
                    },
                  );
                },
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final timeFormat = DateFormat('h:mm a');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isNew ? 'New Interval Timer' : 'Edit Interval Timer',
        ),
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            Text('Timer Name', style: textTheme.titleSmall),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'New Interval Timer',
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              validator: (value) {
                return null;
              },
            ),
            const SizedBox(height: 32),

            _buildSectionHeader('Time Range', textTheme),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  ListTile(
                    title: Text('Start Time', style: textTheme.titleSmall),
                    subtitle: Text(timeFormat.format(_startTime), style: textTheme.bodyMedium),
                    trailing: Icon(Icons.access_time, color: colorScheme.onSurfaceVariant),
                    onTap: _selectStartTime,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  ),
                  Divider(height: 1, color: colorScheme.surfaceContainerHighest),
                  ListTile(
                    title: Text('End Time', style: textTheme.titleSmall),
                    subtitle: Text(timeFormat.format(_endTime), style: textTheme.bodyMedium),
                    trailing: Icon(Icons.access_time, color: colorScheme.onSurfaceVariant),
                    onTap: _selectEndTime,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            _buildSectionHeader('Interval Settings', textTheme),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  ListTile(
                    title: Text('Interval Type', style: textTheme.titleSmall),
                    subtitle: Text(_getIntervalTypeText(), style: textTheme.bodyMedium),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    trailing: DropdownButton<IntervalType>(
                      value: _intervalType,
                      onChanged: (IntervalType? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _intervalType = newValue;
                          });
                        }
                      },
                      items: IntervalType.values.map((IntervalType type) {
                        return DropdownMenuItem<IntervalType>(
                          value: type,
                          child: Text(_getIntervalTypeText(type)),
                        );
                      }).toList(),
                      underline: Container(),
                      icon: Icon(Icons.arrow_drop_down, color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                  Divider(height: 1, color: colorScheme.surfaceContainerHighest),
                  ListTile(
                    title: Text('Interval Value', style: textTheme.titleSmall),
                    subtitle: Text('$_intervalValue ${_getIntervalUnitText()}', style: textTheme.bodyMedium),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, shape: BoxShape.circle),
                          child: IconButton(
                            icon: const Icon(Icons.remove, size: 20),
                            onPressed: _intervalValue > 1 ? () => setState(() => _intervalValue--) : null,
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text('$_intervalValue', style: textTheme.titleMedium),
                        const SizedBox(width: 16),
                        Container(
                          decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
                          child: IconButton(
                            icon: Icon(Icons.add, size: 20, color: colorScheme.primary),
                            onPressed: () => setState(() => _intervalValue++),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: colorScheme.surfaceContainerHighest),
                  ListTile(
                    title: Text('Alarm Sound', style: textTheme.titleSmall),
                    subtitle: Text(_alarmSound.displayName, style: textTheme.bodyMedium),
                    trailing: Icon(Icons.music_note, color: colorScheme.onSurfaceVariant),
                    onTap: _selectAlarmSound,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            _buildSectionHeader('Preview', textTheme),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(Icons.info_outline, color: colorScheme.primary, size: 20),
                    ),
                    title: Text('Summary', style: textTheme.titleSmall),
                    subtitle: Text(
                      'Alarms will sound ${_getIntervalSummary()} between ${timeFormat.format(_startTime)} and ${timeFormat.format(_endTime)}',
                      style: textTheme.bodyMedium,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  Divider(height: 1, color: colorScheme.surfaceContainerHighest),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: colorScheme.secondary.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(Icons.notifications_active, color: colorScheme.secondary, size: 20),
                    ),
                    title: Text('Total Alarms', style: textTheme.titleSmall),
                    subtitle: Text(
                      '${_calculateTotalAlarms()} alarms will be triggered',
                      style: textTheme.bodyMedium,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ],
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
                child: const Text('Save Interval Timer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, TextTheme textTheme) {
    return Text(
      title,
      style: textTheme.titleLarge,
    );
  }

  String _getIntervalTypeText([IntervalType? type]) {
    final intervalType = type ?? _intervalType;
    switch (intervalType) {
      case IntervalType.hour:
        return 'Hours';
      case IntervalType.minute:
        return 'Minutes';
      case IntervalType.second:
        return 'Seconds';
    }
  }

  String _getIntervalUnitText() {
    switch (_intervalType) {
      case IntervalType.hour:
        return _intervalValue == 1 ? 'hour' : 'hours';
      case IntervalType.minute:
        return _intervalValue == 1 ? 'minute' : 'minutes';
      case IntervalType.second:
        return _intervalValue == 1 ? 'second' : 'seconds';
    }
  }

  String _getIntervalSummary() {
    switch (_intervalType) {
      case IntervalType.hour:
        return _intervalValue == 1
            ? 'every hour'
            : 'every $_intervalValue hours';
      case IntervalType.minute:
        return _intervalValue == 1
            ? 'every minute'
            : 'every $_intervalValue minutes';
      case IntervalType.second:
        return _intervalValue == 1
            ? 'every second'
            : 'every $_intervalValue seconds';
    }
  }

  int _calculateTotalAlarms() {
    final tempTimer = IntervalTimer(
      name: '',
      startTime: _startTime,
      endTime: _endTime,
      intervalValue: _intervalValue,
      intervalType: _intervalType,
    );

    return tempTimer.totalAlarms;
  }
}
