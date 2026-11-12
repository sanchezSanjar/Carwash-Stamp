import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../models/stamp_config.dart';
import '../painters/stamp_painter.dart';

class PhotoSaver {
  PhotoSaver._();

  static const album = 'Carwash Stamp';

  static Future<Directory> photosDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}photos');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Burns the stamp into [jpegBytes], saves the result to the app folder and
  /// to the system gallery, and returns the saved file.
  static Future<File> stampAndSave({
    required Uint8List jpegBytes,
    required StampConfig config,
    required ui.Image? logo,
    required DateTime time,
  }) async {
    final codec = await ui.instantiateImageCodec(jpegBytes);
    final frame = await codec.getNextFrame();
    final photo = frame.image;

    final w = photo.width.toDouble();
    final footerH = StampPainter.footerHeightFor(w, config);
    final h = photo.height + footerH;
    final outW = photo.width;
    final outH = h.round();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = Colors.white,
    );
    canvas.drawImage(photo, Offset.zero, Paint());
    StampPainter(config: config, time: time, logo: logo)
        .paint(canvas, Size(w, h));
    final picture = recorder.endRecording();
    final composed = await picture.toImage(outW, outH);
    photo.dispose();

    final raw = await composed.toByteData(format: ui.ImageByteFormat.rawRgba);
    composed.dispose();
    if (raw == null) throw StateError('Could not read composed image');

    final jpeg = await compute(
      _encodeJpeg,
      _EncodeJob(raw.buffer.asUint8List(), outW, outH),
    );

    final dir = await photosDir();
    final name = 'STAMP_${DateFormat('yyyyMMdd_HHmmss').format(time)}.jpg';
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes(jpeg, flush: true);

    try {
      if (!await Gal.hasAccess(toAlbum: true)) {
        await Gal.requestAccess(toAlbum: true);
      }
      await Gal.putImage(file.path, album: album);
    } on GalException catch (e) {
      debugPrint('Gallery save failed: ${e.type}');
    }
    return file;
  }

  static Future<List<File>> savedPhotos() async {
    final dir = await photosDir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.jpg'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return files;
  }
}

class _EncodeJob {
  const _EncodeJob(this.rgba, this.width, this.height);
  final Uint8List rgba;
  final int width;
  final int height;
}

Uint8List _encodeJpeg(_EncodeJob job) {
  final image = img.Image.fromBytes(
    width: job.width,
    height: job.height,
    bytes: job.rgba.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return img.encodeJpg(image, quality: 92);
}
