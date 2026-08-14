import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Thin FlutterTts wrapper. Burst, cap, and mute live in the announcer.
class KdsTtsService {
  KdsTtsService({
    FlutterTts? tts,
    bool? isIos,
  }) : _tts = tts ?? FlutterTts(),
       _isIos = isIos ?? _defaultIsIos;

  final FlutterTts _tts;
  final bool _isIos;

  static bool get _defaultIsIos {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> init() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setQueueMode(1);
      if (!_isIos) {
        return;
      }
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.ambient,
        <IosTextToSpeechAudioCategoryOptions>[
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
      );
    } on Object {
      // Linux and other hosts may have no TTS engine.
    }
  }

  Future<void> speak(String text) async {
    try {
      await _tts.speak(text);
    } on Object {
      // Linux and other hosts may have no TTS engine.
    }
  }

  /// Speaks [text] on the engine queue. Mute is a controller concern, so this
  /// is what Settings uses for the test button (plays even when muted).
  Future<void> speakNow(String text) => speak(text);

  Future<void> stop() async {
    try {
      await _tts.stop();
    } on Object {
      // Same as [speak]: missing engines must not crash the app.
    }
  }
}
