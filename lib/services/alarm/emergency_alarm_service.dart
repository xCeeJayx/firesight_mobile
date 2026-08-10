import 'emergency_alarm_platform.dart';
import 'emergency_alarm_stub.dart'
    if (dart.library.io) 'emergency_alarm_io.dart'
    if (dart.library.js_interop) 'emergency_alarm_web.dart';

class EmergencyAlarmService {
  static final EmergencyAlarmService _instance = EmergencyAlarmService._internal();
  factory EmergencyAlarmService() => _instance;
  EmergencyAlarmService._internal();

  final EmergencyAlarmPlatform _platform = getEmergencyAlarmPlatform();

  /// Starts the continuous emergency siren sound and vibration
  void startAlarm() {
    _platform.startAlarm();
  }

  /// Stops the emergency siren sound and vibration immediately
  void stopAlarm() {
    _platform.stopAlarm();
  }
}
