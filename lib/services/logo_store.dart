import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Loads and caches the logo as a [ui.Image] so the painter can draw it.
///
/// Resolution order: the logo the user picked (copied into the app folder),
/// then the bundled `assets/logo.png` if the app ships one, then nothing.
class LogoStore extends ChangeNotifier {
  ui.Image? _image;
  String? _loadedPath;

  ui.Image? get image => _image;

  Future<void> load(String? path) async {
    if (path == _loadedPath && _image != null) return;
    _loadedPath = path;

    Uint8List? bytes;
    if (path != null && await File(path).exists()) {
      bytes = await File(path).readAsBytes();
    } else {
      try {
        bytes = (await rootBundle.load('assets/logo.png')).buffer.asUint8List();
      } catch (_) {
        bytes = null;
      }
    }

    if (bytes == null) {
      _image = null;
      notifyListeners();
      return;
    }
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _image = frame.image;
    } catch (_) {
      _image = null;
    }
    notifyListeners();
  }

  /// Lets the user pick an image from the gallery and copies it into the app
  /// documents folder so it survives gallery clean-ups. Returns the new path.
  Future<String?> pickFromGallery() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return null;
    final dir = await getApplicationDocumentsDirectory();
    final ext = picked.path.split('.').last.toLowerCase();
    final dest = File(
      '${dir.path}${Platform.pathSeparator}logo_${DateTime.now().millisecondsSinceEpoch}.$ext',
    );
    await File(picked.path).copy(dest.path);
    await load(dest.path);
    return dest.path;
  }
}
