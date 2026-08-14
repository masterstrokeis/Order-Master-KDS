import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android activity is locked to sensor landscape', () {
    final String xml = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(xml, contains('android:screenOrientation="sensorLandscape"'));
  });

  test('iOS supported orientations are landscape only', () {
    final String plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('UIInterfaceOrientationLandscapeLeft'));
    expect(plist, contains('UIInterfaceOrientationLandscapeRight'));
    expect(plist, isNot(contains('UIInterfaceOrientationPortrait')));
  });

  test('main() requests landscape orientations', () {
    final String source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('DeviceOrientation.landscapeLeft'));
    expect(source, contains('DeviceOrientation.landscapeRight'));
    expect(source, contains('setPreferredOrientations'));
  });
}
