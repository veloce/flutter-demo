import 'package:soundpool/soundpool.dart';
import 'package:flutter/services.dart' show rootBundle;

Soundpool _pool = Soundpool.fromOptions();

bool _muted = false;
late int _moveId;
late int _captureId;

Future<void> init() async {
  _moveId = await rootBundle.load('assets/move.mp3').then((soundData) {
    return _pool.load(soundData);
  });

  _captureId = await rootBundle.load('assets/capture.mp3').then((soundData) {
    return _pool.load(soundData);
  });
}

void toggle() {
  _muted = !_muted;
}

bool isMuted() {
  return _muted;
}

void playMove() {
  if (!_muted) _pool.play(_moveId);
}

void playCapture() {
  if (!_muted) _pool.play(_captureId);
}
