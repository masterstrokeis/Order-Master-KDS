import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:order_master_kds/services/kds_tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('init sets en-US language and additive queue mode', () async {
    final _RecordingTts tts = _RecordingTts();
    final KdsTtsService service = KdsTtsService(tts: tts, isIos: false);

    await service.init();

    expect(tts.language, 'en-US');
    expect(tts.queueMode, 1);
    expect(tts.sharedInstance, isNull);
    expect(tts.iosCategory, isNull);
  });

  test('init on iOS sets shared instance and ambient mixWithOthers', () async {
    final _RecordingTts tts = _RecordingTts();
    final KdsTtsService service = KdsTtsService(tts: tts, isIos: true);

    await service.init();

    expect(tts.sharedInstance, isTrue);
    expect(tts.iosCategory, IosTextToSpeechAudioCategory.ambient);
    expect(
      tts.iosOptions,
      <IosTextToSpeechAudioCategoryOptions>[
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
      ],
    );
  });

  test('init swallows engine errors', () async {
    final _RecordingTts tts = _RecordingTts()..throwOnInit = true;
    final KdsTtsService service = KdsTtsService(tts: tts, isIos: false);

    await service.init();

    expect(tts.language, isNull);
    expect(tts.queueMode, isNull);
  });

  test('speak records text and swallows engine errors', () async {
    final _RecordingTts tts = _RecordingTts();
    final KdsTtsService service = KdsTtsService(tts: tts, isIos: false);

    await service.speak('New order 2, table 3.');
    expect(tts.spoken, <String>['New order 2, table 3.']);

    tts.throwOnSpeak = true;
    await service.speak('should not throw');
    expect(tts.spoken, <String>[
      'New order 2, table 3.',
      'should not throw',
    ]);
  });

  test('stop records and swallows engine errors', () async {
    final _RecordingTts tts = _RecordingTts();
    final KdsTtsService service = KdsTtsService(tts: tts, isIos: false);

    await service.stop();
    expect(tts.stopCount, 1);

    tts.throwOnStop = true;
    await service.stop();
    expect(tts.stopCount, 2);
  });

  test('speakNow delegates to speak', () async {
    final _RecordingTts tts = _RecordingTts();
    final KdsTtsService service = KdsTtsService(tts: tts, isIos: false);

    await service.speakNow('This is a test announcement, order 1, table 3.');
    expect(tts.spoken, <String>[
      'This is a test announcement, order 1, table 3.',
    ]);
  });
}

class _RecordingTts extends FlutterTts {
  String? language;
  int? queueMode;
  bool? sharedInstance;
  IosTextToSpeechAudioCategory? iosCategory;
  List<IosTextToSpeechAudioCategoryOptions>? iosOptions;
  final List<String> spoken = <String>[];
  int stopCount = 0;
  bool throwOnInit = false;
  bool throwOnSpeak = false;
  bool throwOnStop = false;

  @override
  Future<dynamic> setLanguage(String language) async {
    if (throwOnInit) {
      throw Exception('no tts engine');
    }
    this.language = language;
    return 1;
  }

  @override
  Future<dynamic> setQueueMode(int queueMode) async {
    this.queueMode = queueMode;
    return 1;
  }

  @override
  Future<dynamic> setSharedInstance(bool sharedSession) async {
    sharedInstance = sharedSession;
    return 1;
  }

  @override
  Future<dynamic> setIosAudioCategory(
    IosTextToSpeechAudioCategory category,
    List<IosTextToSpeechAudioCategoryOptions> options, [
    IosTextToSpeechAudioMode mode = IosTextToSpeechAudioMode.defaultMode,
  ]) async {
    iosCategory = category;
    iosOptions = options;
    return 1;
  }

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    spoken.add(text);
    if (throwOnSpeak) {
      throw Exception('no tts engine');
    }
    return 1;
  }

  @override
  Future<dynamic> stop() async {
    stopCount += 1;
    if (throwOnStop) {
      throw Exception('no tts engine');
    }
    return 1;
  }
}
