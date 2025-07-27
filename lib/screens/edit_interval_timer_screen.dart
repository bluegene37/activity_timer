import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/interval_timer.dart';
import '../models/alarm_sound.dart';
import '../models/settings.dart';
import '../services/database_service.dart';
import '../components/for_ui_card.dart';
import '../components/for_ui_text_field.dart';
import '../theme/for_ui.dart';

class EditIntervalTimerScreen extends StatefulWidget {
  final IntervalTimer timer;
  final bool isNew;

  const EditIntervalTimerScreen({
    super.key,
    required this.timer,
    required this.isNew,
  });

  @override
  State<EditIntervalTimerScreen> createState() => _EditIntervalTimerScreenState();
}

class _EditIntervalTimerScreenState extends State<EditIntervalTimerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _databaseService = DatabaseService();
  final _settings = AppSettings();
  
  late DateTime _startTime;
  late DateTime _endTime;
  late int _intervalValue;
  late IntervalType _intervalType;
  late AlarmSound _alarmSound;
  
  @override
  void initState() {
    super.initState();
    _nameController.text = widget.timer.name;
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
              content: Text('End time must be after start time. Adjusted automatically.'),
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
    
    final updatedTimer = IntervalTimer(
      id: widget.timer.id,
      name: _nameController.text,
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
    
    Navigator.pop(context, true);
  }
  
  void _selectAlarmSound() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
    final timeFormat = DateFormat('h:mm a');
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'New Interval Timer' : 'Edit Interval Timer'),
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(ForUI.spacing),
          children: [
            ForUITextField(
              label: 'Timer Name',
              controller: _nameController,
              hint: 'Enter timer name',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            
            const SizedBox(height: ForUI.spacingLarge),
            
            ForUICard(
              padding: const EdgeInsets.all(ForUI.spacing),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Time Range',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: ForUI.spacingSmall),
                  const Divider(),
                  
                  // Start Time
                  ListTile(
                    title: const Text('Start Time'),
                    subtitle: Text(timeFormat.format(_startTime)),
                    trailing: const Icon(Icons.access_time),
                    onTap: _selectStartTime,
                  ),
                  
                  // End Time
                  ListTile(
                    title: const Text('End Time'),
                    subtitle: Text(timeFormat.format(_endTime)),
                    trailing: const Icon(Icons.access_time),
                    onTap: _selectEndTime,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: ForUI.spacingLarge),
            
            ForUICard(
              padding: const EdgeInsets.all(ForUI.spacing),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Interval Settings',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: ForUI.spacingSmall),
                  const Divider(),
                  
                  // Interval Type
                  ListTile(
                    title: const Text('Interval Type'),
                    subtitle: Text(_getIntervalTypeText()),
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
                    ),
                  ),
                  
                  // Interval Value
                  ListTile(
                    title: const Text('Interval Value'),
                    subtitle: Text('$_intervalValue ${_getIntervalUnitText()}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: _intervalValue > 1 
                              ? () {
                                  setState(() {
                                    _intervalValue--;
                                  });
                                }
                              : null,
                        ),
                        Text(
                          '$_intervalValue',
                          style: theme.textTheme.titleMedium,
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            setState(() {
                              _intervalValue++;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  // Alarm Sound
                  ListTile(
                    title: const Text('Alarm Sound'),
                    subtitle: Text(_alarmSound.displayName),
                    trailing: const Icon(Icons.music_note),
                    onTap: _selectAlarmSound,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: ForUI.spacingLarge),
            
            // Preview
            ForUICard(
              padding: const EdgeInsets.all(ForUI.spacing),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preview',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: ForUI.spacingSmall),
                  const Divider(),
                  
                  // Summary
                  ListTile(
                    leading: Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('Summary'),
                    subtitle: Text(
                      'Alarms will sound ${_getIntervalSummary()} between ${timeFormat.format(_startTime)} and ${timeFormat.format(_endTime)}',
                    ),
                  ),
                  
                  // Total alarms
                  ListTile(
                    leading: Icon(
                      Icons.notifications_active,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('Total Alarms'),
                    subtitle: Text(
                      '${_calculateTotalAlarms()} alarms will be triggered',
                    ),
                  ),
                  
                  // Alarm sound
                  ListTile(
                    leading: Icon(
                      Icons.volume_up,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('Alarm Sound'),
                    subtitle: Text(_alarmSound.displayName),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
