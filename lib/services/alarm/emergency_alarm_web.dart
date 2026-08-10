import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'emergency_alarm_platform.dart';
import 'siren_sound_generator.dart';

class EmergencyAlarmPlatformWeb implements EmergencyAlarmPlatform {
  AudioPlayer? _audioPlayer;
  Timer? _vibrationTimer;
  bool _isPlaying = false;

  @override
  void startAlarm() {
    if (_isPlaying) return;
    _isPlaying = true;

    // 1. Play siren audio via AudioPlayer or Web Audio
    _startAudio();

    // 2. Start Web navigator vibration & haptic pulses
    _startVibration();
  }

  Future<void> _startAudio() async {
    try {
      _audioPlayer?.dispose();
      _audioPlayer = AudioPlayer();
      await _audioPlayer!.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer!.setVolume(1.0);
      final wavBytes = SirenSoundGenerator.getSirenWavBytes();
      await _audioPlayer!.play(BytesSource(wavBytes));
    } catch (_) {}
  }

  void _startVibration() {
    _pulseWebVibration();

    _vibrationTimer?.cancel();
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (!_isPlaying) {
        timer.cancel();
        return;
      }
      _pulseWebVibration();
    });
  }

  void _pulseWebVibration() {
    try {
      final nav = globalContext.getProperty('navigator'.toJS) as JSObject?;
      if (nav != null && nav.hasProperty('vibrate'.toJS).toDart) {
        final pattern = <JSNumber>[500.toJS, 200.toJS, 500.toJS].toJS;
        nav.callMethod('vibrate'.toJS, pattern);
      }
    } catch (_) {}

    try {
      HapticFeedback.vibrate();
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  @override
  void stopAlarm() {
    _isPlaying = false;
    _vibrationTimer?.cancel();
    _vibrationTimer = null;

    try {
      _audioPlayer?.stop();
      _audioPlayer?.dispose();
      _audioPlayer = null;
    } catch (_) {}

    try {
      final nav = globalContext.getProperty('navigator'.toJS) as JSObject?;
      if (nav != null && nav.hasProperty('vibrate'.toJS).toDart) {
        nav.callMethod('vibrate'.toJS, 0.toJS);
      }
    } catch (_) {}
  }
}

EmergencyAlarmPlatform getEmergencyAlarmPlatform() => EmergencyAlarmPlatformWeb();
