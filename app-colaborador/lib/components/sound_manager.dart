import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:web/web.dart' as web;

class SoundManager {
  static final AudioPlayer _player = AudioPlayer();

  // URLs for public domain sound effects
  static const String _successUrl = 'https://assets.mixkit.co/active_storage/sfx/2018/2018-84.wav';
  static const String _errorUrl = 'https://assets.mixkit.co/active_storage/sfx/2019/2019-84.wav';
  static const String _fanfareUrl = 'https://assets.mixkit.co/active_storage/sfx/2017/2017-84.wav';

  static Future<void> playSuccess() async {
    if (kIsWeb) {
      _playWebSynth(880, 'sine', 0.15); // Clear high tone
    }
    try {
      await _player.stop();
      await _player.play(UrlSource(_successUrl));
    } catch (e) {
      debugPrint('Error playing success sound: $e');
    }
  }

  static Future<void> playError() async {
    if (kIsWeb) {
      _playWebSynth(220, 'triangle', 0.25); // Lower soft tone
    }
    try {
      await _player.stop();
      await _player.play(UrlSource(_errorUrl));
    } catch (e) {
      debugPrint('Error playing error sound: $e');
    }
  }

  static Future<void> playFanfare() async {
    if (kIsWeb) {
      // Short synthesized fanfare melody
      _playWebSynthFanfare();
    }
    try {
      await _player.stop();
      await _player.play(UrlSource(_fanfareUrl));
    } catch (e) {
      debugPrint('Error playing fanfare sound: $e');
    }
  }

  // Fallback synthesized sounds using Web Audio API via JS Interop
  static void _playWebSynth(double frequency, String type, double duration) {
    try {
      final audioCtx = web.AudioContext();
      final oscillator = audioCtx.createOscillator();
      final gainNode = audioCtx.createGain();

      oscillator.type = type;
      oscillator.frequency.setValueAtTime(frequency, audioCtx.currentTime);
      
      gainNode.gain.setValueAtTime(0.1, audioCtx.currentTime);
      gainNode.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + duration);

      oscillator.connect(gainNode);
      gainNode.connect(audioCtx.destination);

      oscillator.start();
      oscillator.stop(audioCtx.currentTime + duration);
    } catch (e) {
      debugPrint('Web audio synthesis failed: $e');
    }
  }

  static void _playWebSynthFanfare() {
    try {
      final audioCtx = web.AudioContext();
      final notes = [523.25, 659.25, 783.99, 1046.50]; // C5, E5, G5, C6
      final durations = [0.1, 0.1, 0.1, 0.4];
      final startTimes = [0.0, 0.12, 0.24, 0.36];

      for (int i = 0; i < notes.length; i++) {
        final osc = audioCtx.createOscillator();
        final gain = audioCtx.createGain();

        osc.type = 'triangle';
        osc.frequency.setValueAtTime(notes[i], audioCtx.currentTime + startTimes[i]);

        gain.gain.setValueAtTime(0.1, audioCtx.currentTime + startTimes[i]);
        gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + startTimes[i] + durations[i]);

        osc.connect(gain);
        gain.connect(audioCtx.destination);

        osc.start(audioCtx.currentTime + startTimes[i]);
        osc.stop(audioCtx.currentTime + startTimes[i] + durations[i]);
      }
    } catch (e) {
      debugPrint('Web fanfare synthesis failed: $e');
    }
  }
}
