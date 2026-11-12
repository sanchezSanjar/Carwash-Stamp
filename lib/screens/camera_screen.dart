import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:material_ui/material_ui.dart';

import '../models/stamp_config.dart';
import '../painters/stamp_painter.dart';
import '../services/logo_store.dart';
import '../services/photo_saver.dart';
import 'gallery_screen.dart';
import 'settings_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({
    super.key,
    required this.cameras,
    required this.initialConfig,
    required this.logoStore,
  });

  final List<CameraDescription> cameras;
  final StampConfig initialConfig;
  final LogoStore logoStore;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  late StampConfig _config;
  DateTime _now = DateTime.now();
  Timer? _clock;
  bool _busy = false;
  bool _flashOn = false;
  File? _lastPhoto;
  String? _error;

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
    WidgetsBinding.instance.addObserver(this);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    widget.logoStore.addListener(_onLogoChanged);
    _openCamera();
    PhotoSaver.savedPhotos().then((files) {
      if (mounted && files.isNotEmpty) setState(() => _lastPhoto = files.first);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.logoStore.removeListener(_onLogoChanged);
    _clock?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _onLogoChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _openCamera();
    }
  }

  ResolutionPreset get _preset => switch (_config.quality) {
        CaptureQuality.high => ResolutionPreset.high,
        CaptureQuality.veryHigh => ResolutionPreset.veryHigh,
        CaptureQuality.ultraHigh => ResolutionPreset.ultraHigh,
        CaptureQuality.max => ResolutionPreset.max,
      };

  Future<void> _openCamera() async {
    if (widget.cameras.isEmpty) {
      setState(() => _error = 'No camera found on this device.');
      return;
    }
    final index = _config.cameraIndex.clamp(0, widget.cameras.length - 1);
    final old = _controller;
    _controller = null;
    await old?.dispose();

    final controller = CameraController(
      widget.cameras[index],
      _preset,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await controller.initialize();
      await controller.setFlashMode(_flashOn ? FlashMode.auto : FlashMode.off);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _error = null;
      });
    } on CameraException catch (e) {
      setState(() => _error = e.description ?? e.code);
    }
  }

  Future<void> _flipCamera() async {
    if (widget.cameras.length < 2) return;
    _config = _config.copyWith(
      cameraIndex: (_config.cameraIndex + 1) % widget.cameras.length,
    );
    await _config.save();
    await _openCamera();
  }

  Future<void> _toggleFlash() async {
    final c = _controller;
    if (c == null) return;
    _flashOn = !_flashOn;
    await c.setFlashMode(_flashOn ? FlashMode.auto : FlashMode.off);
    setState(() {});
  }

  Future<void> _openSettings() async {
    final updated = await Navigator.of(context).push<StampConfig>(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          config: _config,
          logoStore: widget.logoStore,
        ),
      ),
    );
    if (updated == null || !mounted) return;
    final qualityChanged = updated.quality != _config.quality;
    setState(() => _config = updated);
    if (qualityChanged) await _openCamera();
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _busy) return;
    setState(() => _busy = true);
    final time = DateTime.now();
    try {
      final shot = await c.takePicture();
      final bytes = await shot.readAsBytes();
      final file = await PhotoSaver.stampAndSave(
        jpegBytes: bytes,
        config: _config,
        logo: widget.logoStore.image,
        time: time,
      );
      if (!mounted) return;
      setState(() => _lastPhoto = file);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved to gallery'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save photo: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              flashOn: _flashOn,
              onFlash: _toggleFlash,
              onSettings: _openSettings,
            ),
            Expanded(child: _buildPreview()),
            _BottomBar(
              busy: _busy,
              lastPhoto: _lastPhoto,
              canFlip: widget.cameras.length > 1,
              onCapture: _capture,
              onFlip: _flipCamera,
              onGallery: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GalleryScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(error,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center),
        ),
      );
    }
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    // Camera reports aspect ratio in landscape terms; the app is portrait.
    final photoRatio = c.value.aspectRatio; // height / width in portrait
    final footerRatio = _config.footerEnabled ? 0.14 : 0.0;

    return LayoutBuilder(
      builder: (context, box) {
        var w = box.maxWidth;
        var totalH = w * (photoRatio + footerRatio);
        if (totalH > box.maxHeight) {
          totalH = box.maxHeight;
          w = totalH / (photoRatio + footerRatio);
        }
        final photoH = w * photoRatio;
        return Center(
          child: SizedBox(
            width: w,
            height: totalH,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  width: w,
                  height: photoH,
                  child: CameraPreview(c),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: StampPainter(
                        config: _config,
                        time: _now,
                        logo: widget.logoStore.image,
                      ),
                    ),
                  ),
                ),
                if (_busy)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black45,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 12),
                            Text('Saving...',
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.flashOn,
    required this.onFlash,
    required this.onSettings,
  });

  final bool flashOn;
  final VoidCallback onFlash;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: flashOn ? 'Flash auto' : 'Flash off',
            onPressed: onFlash,
            icon: Icon(
              flashOn ? Icons.flash_auto : Icons.flash_off,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Settings',
            onPressed: onSettings,
            icon: const Icon(Icons.tune, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.busy,
    required this.lastPhoto,
    required this.canFlip,
    required this.onCapture,
    required this.onFlip,
    required this.onGallery,
  });

  final bool busy;
  final File? lastPhoto;
  final bool canFlip;
  final VoidCallback onCapture;
  final VoidCallback onFlip;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: onGallery,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white54),
                color: Colors.white10,
              ),
              clipBehavior: Clip.antiAlias,
              child: lastPhoto == null
                  ? const Icon(Icons.photo_library_outlined,
                      color: Colors.white70)
                  : Image.file(lastPhoto!, fit: BoxFit.cover,
                      key: ValueKey(lastPhoto!.path)),
            ),
          ),
          GestureDetector(
            onTap: busy ? null : onCapture,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              padding: const EdgeInsets.all(6),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: busy ? Colors.white38 : Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 56,
            height: 56,
            child: canFlip
                ? IconButton(
                    onPressed: onFlip,
                    iconSize: 32,
                    icon: const Icon(Icons.cameraswitch_outlined,
                        color: Colors.white),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
