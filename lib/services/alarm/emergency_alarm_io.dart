import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'emergency_alarm_platform.dart';
import 'siren_sound_generator.dart';

class EmergencyAlarmPlatformIO implements EmergencyAlarmPlatform {
  AudioPlayer? _audioPlayer;
  Timer? _vibrationTimer;
  bool _isPlaying = false;

  @override
  void startAlarm() {
    if (_isPlaying) return;
    _isPlaying = true;

    debugPrint('🚨 [EmergencyAlarm] Starting Alarm & Phone Vibration...');

    // 1. Play offline synthesized emergency alarm siren audio in continuous loop
    _startAudio();

    // 2. Start continuous hardware vibration pattern
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
    } catch (e) {
      debugPrint('🚨 [EmergencyAlarm] Audio play fallback: $e');
      _startFallbackSound();
    }
  }

  void _startFallbackSound() {
    Timer.periodic(const Duration(milliseconds: 650), (timer) {
      if (!_isPlaying) {
        timer.cancel();
        return;
      }
      try {
        SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    });
  }

  Future<void> _startVibration() async {
    // 1. Try native continuous waveform vibration with proper timings
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        // Pattern: [delayMs, vibrateMs, pauseMs, vibrateMs, ...]
        // repeat: 0 repeats indefinitely starting from index 0 until cancel()
        await Vibration.vibrate(
          pattern: [0, 800, 250, 800, 250],
          repeat: 0,
        );
      }
    } catch (e) {
      debugPrint('🚨 [EmergencyAlarm] Vibration.vibrate error: $e');
    }

    // 2. ALWAYS run active periodic HapticFeedback & Vibration pulses in parallel
    // to guarantee vibration across all Android OEM skins (Samsung, Xiaomi, Vivo, etc.) and iOS
    _vibrationTimer?.cancel();
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (!_isPlaying) {
        timer.cancel();
        return;
      }
      try {
        HapticFeedback.vibrate();
        HapticFeedback.heavyImpact();
      } catch (_) {}
    });
  }

  @override
  void stopAlarm() {
    debugPrint('🚨 [EmergencyAlarm] Stopping Alarm & Vibration...');
    _isPlaying = false;
    _vibrationTimer?.cancel();
    _vibrationTimer = null;

    // Stop audio
    try {
      _audioPlayer?.stop();
      _audioPlayer?.dispose();
      _audioPlayer = null;
    } catch (_) {}

    // Cancel hardware vibration
    try {
      Vibration.cancel();
    } catch (_) {}
  }
}

EmergencyAlarmPlatform getEmergencyAlarmPlatform() => EmergencyAlarmPlatformIO();
