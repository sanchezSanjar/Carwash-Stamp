import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../models/stamp_config.dart';

/// Draws the stamp overlay. The same painter is used for the live preview and
/// for the final photo, so what you see is what gets saved.
///
/// All sizes are expressed as a fraction of the output width, so the layout
/// scales identically no matter the resolution. [size] is the full output
/// including the footer band; the photo occupies the top
/// `size.height - footerHeight`.
class StampPainter extends CustomPainter {
  StampPainter({
    required this.config,
    required this.time,
    this.logo,
    this.fontFamily,
  });

  final StampConfig config;
  final DateTime time;
  final ui.Image? logo;

  /// Normally null (platform default font). Tests pass a loaded font here.
  final String? fontFamily;

  static const _footerRatio = 0.14;

  /// Height of the white footer band for an output of [width].
  static double footerHeightFor(double width, StampConfig config) =>
      config.footerEnabled ? width * _footerRatio : 0;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 100;
    final s = config.stampScale;
    final footerH = footerHeightFor(size.width, config);
    final photoH = size.height - footerH;
    final margin = 2.5 * u;

    // ---- Date row ---------------------------------------------------------
    final dateFont = 3.3 * u * s;
    final dateRowH = dateFont * 1.3;
    final dateTop = photoH - margin - dateRowH;

    // ---- Banner -----------------------------------------------------------
    final bannerH = 7.5 * u * s;
    final bannerTop = dateTop - 1.2 * u * s - bannerH;

    // ---- Stars ------------------------------------------------------------
    final starSize = 2.6 * u * s;
    final starsTop = bannerTop - 0.9 * u * s - starSize;

    if (config.showStars && config.starCount > 0) {
      _drawStars(canvas, Offset(margin + 0.6 * u, starsTop), starSize);
    }

    _drawBanner(canvas, u, s, margin, bannerTop, bannerH);

    if (config.showDate) {
      _drawDateRow(canvas, u, margin, dateTop, dateRowH, dateFont);
    }

    if (config.footerEnabled) {
      _drawFooter(canvas, size, u, photoH, footerH, margin);
    }
  }

  // --------------------------------------------------------------------------

  void _drawStars(Canvas canvas, Offset origin, double size) {
    final paint = Paint()..color = const Color(0xFFFFC107);
    for (var i = 0; i < config.starCount; i++) {
      final center = origin + Offset(i * size * 1.12 + size / 2, size / 2);
      canvas.drawPath(_starPath(center, size / 2), paint);
    }
  }

  /// Five-pointed star, drawn as a path so it never depends on an icon font.
  static Path _starPath(Offset c, double r) {
    const points = 5;
    final inner = r * 0.46;
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final radius = i.isEven ? r : inner;
      final angle = -math.pi / 2 + i * math.pi / points;
      final p = Offset(
        c.dx + radius * math.cos(angle),
        c.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  void _drawBanner(
    Canvas canvas,
    double u,
    double s,
    double margin,
    double top,
    double h,
  ) {
    final pad = 2.0 * u * s;
    var x = margin;
    final radius = Radius.circular(0.8 * u);

    // Title box.
    final title = config.titleText.trim();
    if (title.isNotEmpty) {
      final tp = _textPainter(
        title,
        4.3 * u * s,
        Colors.white,
        FontWeight.w800,
      );
      final w = tp.width + pad * 2;
      final rect = Rect.fromLTWH(x, top, w, h);
      final base = Color(config.bannerColor);
      final paint = Paint()
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          rect.bottomLeft,
          [_lighten(base, 0.12), base],
        );
      canvas.drawRRect(
        RRect.fromRectAndCorners(rect, topLeft: radius, bottomLeft: radius),
        paint,
      );
      tp.paint(canvas, Offset(x + pad, top + (h - tp.height) / 2));
      x += w;
    }

    // Time box.
    if (config.showTime) {
      final tp = _textPainter(
        config.formatTime(time),
        4.6 * u * s,
        Colors.white,
        FontWeight.w900,
      );
      final w = tp.width + pad * 2;
      final rect = Rect.fromLTWH(x, top, w, h);
      canvas.drawRect(rect, Paint()..color = Color(config.timeBoxColor));
      tp.paint(canvas, Offset(x + pad, top + (h - tp.height) / 2));
      x += w;
    }

    // Logo box (always square, white).
    final logoRect = Rect.fromLTWH(x, top, h, h);
    canvas.drawRRect(
      RRect.fromRectAndCorners(logoRect, topRight: radius, bottomRight: radius),
      Paint()..color = Colors.white,
    );
    _drawLogo(canvas, logoRect.deflate(0.5 * u * s), u);
  }

  void _drawDateRow(
    Canvas canvas,
    double u,
    double margin,
    double top,
    double rowH,
    double font,
  ) {
    final bar = Rect.fromLTWH(margin, top, 0.8 * u, rowH);
    canvas.drawRect(bar, Paint()..color = Color(config.bannerColor));
    final tp = _textPainter(
      config.formatDate(time),
      font,
      const Color(0xFF1E1E1E),
      FontWeight.w600,
    );
    // Soft white glow behind the dark text so it stays readable on dark photos.
    final glow = _textPainter(
      config.formatDate(time),
      font,
      Colors.white.withValues(alpha: 0.55),
      FontWeight.w600,
      strokeWidth: 0.3 * u,
    );
    final pos = Offset(margin + 2.4 * u, top + (rowH - tp.height) / 2);
    glow.paint(canvas, pos);
    tp.paint(canvas, pos);
  }

  void _drawFooter(
    Canvas canvas,
    Size size,
    double u,
    double top,
    double h,
    double margin,
  ) {
    canvas.drawRect(
      Rect.fromLTWH(0, top, size.width, h),
      Paint()..color = Colors.white,
    );
    final logoH = h * 0.66;
    final logoW = _logoWidthFor(logoH);
    final centerY = top + h / 2;

    // Left logo.
    _drawLogo(
      canvas,
      Rect.fromLTWH(margin, centerY - logoH / 2, logoW, logoH),
      u,
    );
    // Right logo.
    _drawLogo(
      canvas,
      Rect.fromLTWH(size.width - margin - logoW, centerY - logoH / 2, logoW,
          logoH),
      u,
    );
    // Footer text.
    final text = config.footerText.trim();
    if (text.isNotEmpty) {
      final tp = _textPainter(
        text,
        4.8 * u,
        const Color(0xFF222222),
        FontWeight.w700,
      );
      tp.paint(
        canvas,
        Offset(margin + logoW + 2.5 * u, centerY - tp.height / 2),
      );
    }
  }

  double _logoWidthFor(double h) {
    final img = logo;
    if (img == null) return h;
    return h * img.width / img.height;
  }

  /// Draws the logo fitted inside [rect]. Falls back to a camera glyph when no
  /// logo has been chosen yet.
  void _drawLogo(Canvas canvas, Rect rect, double u) {
    final img = logo;
    if (img == null) {
      final size = rect.shortestSide * 0.8;
      final tp = _iconPainter(
        Icons.photo_camera_outlined,
        size,
        const Color(0xFF9E9E9E),
      );
      tp.paint(
        canvas,
        Offset(
          rect.center.dx - tp.width / 2,
          rect.center.dy - tp.height / 2,
        ),
      );
      return;
    }
    final fitted = applyBoxFit(
      BoxFit.contain,
      Size(img.width.toDouble(), img.height.toDouble()),
      rect.size,
    );
    final dst = Alignment.center.inscribe(fitted.destination, rect);
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      dst,
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  // --------------------------------------------------------------------------

  TextPainter _textPainter(
    String text,
    double fontSize,
    Color color,
    FontWeight weight, {
    double? strokeWidth,
  }) {
    final style = TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: weight,
      color: strokeWidth == null ? color : null,
      foreground: strokeWidth == null
          ? null
          : (Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeJoin = StrokeJoin.round
            ..color = color),
      height: 1.0,
    );
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
  }

  TextPainter _iconPainter(IconData icon, double size, Color color) {
    return TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  static Color _lighten(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  bool shouldRepaint(StampPainter old) =>
      old.config != config || old.time != time || old.logo != logo;
}
