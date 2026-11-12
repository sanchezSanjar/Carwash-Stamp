import 'package:material_ui/material_ui.dart';

import '../models/stamp_config.dart';
import '../painters/stamp_painter.dart';
import '../services/logo_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.config,
    required this.logoStore,
  });

  final StampConfig config;
  final LogoStore logoStore;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late StampConfig _c;
  late final TextEditingController _title;
  late final TextEditingController _footer;

  static const _bannerColors = <int>[
    0xFF2E7BD6, // blue (default)
    0xFF1565C0,
    0xFF00897B,
    0xFF43A047,
    0xFFE53935,
    0xFFF4511E,
    0xFF8E24AA,
    0xFF212121,
  ];

  @override
  void initState() {
    super.initState();
    _c = widget.config;
    _title = TextEditingController(text: _c.titleText);
    _footer = TextEditingController(text: _c.footerText);
    widget.logoStore.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.logoStore.removeListener(_refresh);
    _title.dispose();
    _footer.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _update(StampConfig next) {
    setState(() => _c = next);
    next.save();
  }

  Future<void> _pickLogo() async {
    final path = await widget.logoStore.pickFromGallery();
    if (path != null) _update(_c.copyWith(logoPath: path));
  }

  Future<void> _clearLogo() async {
    _update(_c.copyWith(clearLogo: true));
    await widget.logoStore.load(null);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_c);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Stamp settings'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_c),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _Preview(config: _c, logoStore: widget.logoStore),
            const _Header('Banner'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Title text',
                  hintText: '세차완료',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _update(_c.copyWith(titleText: v)),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Show stars'),
              value: _c.showStars,
              onChanged: (v) => _update(_c.copyWith(showStars: v)),
            ),
            if (_c.showStars)
              ListTile(
                title: const Text('Number of stars'),
                trailing: DropdownButton<int>(
                  value: _c.starCount,
                  items: [1, 2, 3, 4, 5]
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                      .toList(),
                  onChanged: (v) =>
                      v == null ? null : _update(_c.copyWith(starCount: v)),
                ),
              ),
            ListTile(
              title: const Text('Banner colour'),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 10,
                  children: _bannerColors.map((argb) {
                    final selected = argb == _c.bannerColor;
                    return GestureDetector(
                      onTap: () => _update(_c.copyWith(
                        bannerColor: argb,
                        timeBoxColor: _darker(argb),
                      )),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Color(argb),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? Colors.white : Colors.white24,
                            width: selected ? 3 : 1,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            ListTile(
              title: const Text('Stamp size'),
              subtitle: Slider(
                value: _c.stampScale,
                min: 0.7,
                max: 1.5,
                divisions: 16,
                label: '${(_c.stampScale * 100).round()}%',
                onChanged: (v) => _update(_c.copyWith(stampScale: v)),
              ),
            ),
            const _Header('Date and time'),
            SwitchListTile(
              title: const Text('Show time in banner'),
              value: _c.showTime,
              onChanged: (v) => _update(_c.copyWith(showTime: v)),
            ),
            if (_c.showTime) ...[
              SwitchListTile(
                title: const Text('24-hour clock'),
                value: _c.use24h,
                onChanged: (v) => _update(_c.copyWith(use24h: v)),
              ),
              SwitchListTile(
                title: const Text('Show seconds'),
                value: _c.showSeconds,
                onChanged: (v) => _update(_c.copyWith(showSeconds: v)),
              ),
            ],
            SwitchListTile(
              title: const Text('Show date under banner'),
              value: _c.showDate,
              onChanged: (v) => _update(_c.copyWith(showDate: v)),
            ),
            if (_c.showDate)
              ListTile(
                title: const Text('Date format'),
                trailing: DropdownButton<DateStyle>(
                  value: _c.dateStyle,
                  items: DateStyle.values
                      .map((d) =>
                          DropdownMenuItem(value: d, child: Text(d.label)))
                      .toList(),
                  onChanged: (v) =>
                      v == null ? null : _update(_c.copyWith(dateStyle: v)),
                ),
              ),
            const _Header('Logo'),
            ListTile(
              leading: SizedBox(
                width: 48,
                height: 48,
                child: widget.logoStore.image == null
                    ? const Icon(Icons.image_not_supported_outlined)
                    : CustomPaint(
                        painter: _LogoThumb(widget.logoStore.image!),
                      ),
              ),
              title: Text(_c.logoPath == null
                  ? (widget.logoStore.image == null
                      ? 'No logo chosen'
                      : 'Using built-in logo')
                  : 'Custom logo'),
              subtitle: const Text('Shown in the banner and footer'),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: 'Choose from gallery',
                    icon: const Icon(Icons.photo_library_outlined),
                    onPressed: _pickLogo,
                  ),
                  if (_c.logoPath != null)
                    IconButton(
                      tooltip: 'Remove custom logo',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _clearLogo,
                    ),
                ],
              ),
            ),
            const _Header('Footer'),
            SwitchListTile(
              title: const Text('Add white footer below photo'),
              value: _c.footerEnabled,
              onChanged: (v) => _update(_c.copyWith(footerEnabled: v)),
            ),
            if (_c.footerEnabled)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _footer,
                  decoration: const InputDecoration(
                    labelText: 'Footer text',
                    hintText: '감사합니다',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => _update(_c.copyWith(footerText: v)),
                ),
              ),
            const _Header('Camera'),
            ListTile(
              title: const Text('Photo resolution'),
              subtitle: Text(_c.quality.label),
              trailing: DropdownButton<CaptureQuality>(
                value: _c.quality,
                items: CaptureQuality.values
                    .map((q) => DropdownMenuItem(value: q, child: Text(q.name)))
                    .toList(),
                onChanged: (v) =>
                    v == null ? null : _update(_c.copyWith(quality: v)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static int _darker(int argb) {
    final hsl = HSLColor.fromColor(Color(argb));
    return hsl
        .withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0))
        .toColor()
        .toARGB32();
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

/// Live preview of the stamp on a fake photo so edits are visible instantly.
class _Preview extends StatelessWidget {
  const _Preview({required this.config, required this.logoStore});
  final StampConfig config;
  final LogoStore logoStore;

  @override
  Widget build(BuildContext context) {
    final footer = config.footerEnabled ? 0.14 : 0.0;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 1 / (0.75 + footer),
          child: CustomPaint(
            painter: _FakePhotoPainter(),
            foregroundPainter: StampPainter(
              config: config,
              time: DateTime.now(),
              logo: logoStore.image,
            ),
          ),
        ),
      ),
    );
  }
}

class _FakePhotoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF607D8B), Color(0xFF263238)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_FakePhotoPainter old) => false;
}

class _LogoThumb extends CustomPainter {
  _LogoThumb(this.image);
  final dynamic image;

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
        0, 0, image.width.toDouble(), image.height.toDouble());
    final fitted = applyBoxFit(BoxFit.contain, src.size, size);
    final dst = Alignment.center.inscribe(fitted.destination, Offset.zero & size);
    canvas.drawImageRect(image, src, dst, Paint());
  }

  @override
  bool shouldRepaint(_LogoThumb old) => old.image != image;
}
