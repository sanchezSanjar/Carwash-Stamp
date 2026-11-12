// Renders the stamp onto a photo with the real painter and writes a PNG, so the
// layout can be checked without a device.
//
//   flutter test test/stamp_render_test.dart --dart-define=PHOTO=<in.jpg> --dart-define=OUT=<out.png>
//
// Optional: --dart-define=FONT=<path.ttf> (repeat faces separated by ';') to
// render text with a real font instead of the test framework's box glyphs.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:carwash_stamp/models/stamp_config.dart';
import 'package:carwash_stamp/painters/stamp_painter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _photoPath = String.fromEnvironment('PHOTO');
const _outPath = String.fromEnvironment('OUT');
const _fontPaths = String.fromEnvironment('FONT');

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  return (await codec.getNextFrame()).image;
}

void main() {
  testWidgets('renders stamped photo', (tester) async {
    if (_photoPath.isEmpty || _outPath.isEmpty) {
      markTestSkipped('PHOTO and OUT dart-defines not set');
      return;
    }
    await tester.runAsync(() async {
      String? family;
      if (_fontPaths.isNotEmpty) {
        family = 'StampTestFont';
        final loader = FontLoader(family);
        for (final p in _fontPaths.split(';')) {
          final data = await File(p).readAsBytes();
          loader.addFont(Future.value(ByteData.view(data.buffer)));
        }
        await loader.load();
      }

      final photo = await _decode(await File(_photoPath).readAsBytes());
      final logoData = await rootBundle.load('assets/logo.png');
      final logo = await _decode(logoData.buffer.asUint8List());

      const config = StampConfig();
      final time = DateTime(2026, 11, 12, 4, 19);

      final w = photo.width.toDouble();
      final footerH = StampPainter.footerHeightFor(w, config);
      final h = photo.height + footerH;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = Colors.white);
      canvas.drawImage(photo, Offset.zero, Paint());
      StampPainter(config: config, time: time, logo: logo, fontFamily: family)
          .paint(canvas, Size(w, h));
      final image =
          await recorder.endRecording().toImage(photo.width, h.round());
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(_outPath).writeAsBytes(png!.buffer.asUint8List());
      expect(File(_outPath).existsSync(), isTrue);
    });
  });
}
