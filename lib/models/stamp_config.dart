import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DateStyle { dmy, mdy, ymd, long }

extension DateStyleFormat on DateStyle {
  String get label => switch (this) {
        DateStyle.dmy => '12/11/2026',
        DateStyle.mdy => '11/12/2026',
        DateStyle.ymd => '2026-11-12',
        DateStyle.long => '12 Nov 2026',
      };

  String get pattern => switch (this) {
        DateStyle.dmy => 'dd/MM/yyyy',
        DateStyle.mdy => 'MM/dd/yyyy',
        DateStyle.ymd => 'yyyy-MM-dd',
        DateStyle.long => 'dd MMM yyyy',
      };
}

enum CaptureQuality { high, veryHigh, ultraHigh, max }

extension CaptureQualityLabel on CaptureQuality {
  String get label => switch (this) {
        CaptureQuality.high => '1080p (fastest)',
        CaptureQuality.veryHigh => '2160p (recommended)',
        CaptureQuality.ultraHigh => '4K and above',
        CaptureQuality.max => 'Maximum the camera supports',
      };
}

/// Everything that controls how the stamp is drawn. Immutable; use [copyWith].
class StampConfig {
  const StampConfig({
    this.titleText = '세차완료',
    this.showStars = true,
    this.starCount = 5,
    this.showTime = true,
    this.use24h = true,
    this.showSeconds = false,
    this.showDate = true,
    this.dateStyle = DateStyle.dmy,
    this.bannerColor = 0xFF2E7BD6,
    this.timeBoxColor = 0xFF1A56B0,
    this.logoPath,
    this.footerEnabled = true,
    this.footerText = '감사합니다',
    this.stampScale = 1.0,
    this.quality = CaptureQuality.veryHigh,
    this.cameraIndex = 0,
  });

  final String titleText;
  final bool showStars;
  final int starCount;
  final bool showTime;
  final bool use24h;
  final bool showSeconds;
  final bool showDate;
  final DateStyle dateStyle;
  final int bannerColor;
  final int timeBoxColor;
  final String? logoPath;
  final bool footerEnabled;
  final String footerText;
  final double stampScale;
  final CaptureQuality quality;
  final int cameraIndex;

  static const _prefsKey = 'stamp_config_v2';

  String formatTime(DateTime t) {
    final pattern = use24h
        ? (showSeconds ? 'HH:mm:ss' : 'HH:mm')
        : (showSeconds ? 'hh:mm:ss a' : 'hh:mm a');
    return DateFormat(pattern).format(t);
  }

  String formatDate(DateTime t) => DateFormat(dateStyle.pattern).format(t);

  StampConfig copyWith({
    String? titleText,
    bool? showStars,
    int? starCount,
    bool? showTime,
    bool? use24h,
    bool? showSeconds,
    bool? showDate,
    DateStyle? dateStyle,
    int? bannerColor,
    int? timeBoxColor,
    String? logoPath,
    bool clearLogo = false,
    bool? footerEnabled,
    String? footerText,
    double? stampScale,
    CaptureQuality? quality,
    int? cameraIndex,
  }) {
    return StampConfig(
      titleText: titleText ?? this.titleText,
      showStars: showStars ?? this.showStars,
      starCount: starCount ?? this.starCount,
      showTime: showTime ?? this.showTime,
      use24h: use24h ?? this.use24h,
      showSeconds: showSeconds ?? this.showSeconds,
      showDate: showDate ?? this.showDate,
      dateStyle: dateStyle ?? this.dateStyle,
      bannerColor: bannerColor ?? this.bannerColor,
      timeBoxColor: timeBoxColor ?? this.timeBoxColor,
      logoPath: clearLogo ? null : (logoPath ?? this.logoPath),
      footerEnabled: footerEnabled ?? this.footerEnabled,
      footerText: footerText ?? this.footerText,
      stampScale: stampScale ?? this.stampScale,
      quality: quality ?? this.quality,
      cameraIndex: cameraIndex ?? this.cameraIndex,
    );
  }

  Map<String, dynamic> toJson() => {
        'titleText': titleText,
        'showStars': showStars,
        'starCount': starCount,
        'showTime': showTime,
        'use24h': use24h,
        'showSeconds': showSeconds,
        'showDate': showDate,
        'dateStyle': dateStyle.name,
        'bannerColor': bannerColor,
        'timeBoxColor': timeBoxColor,
        'logoPath': logoPath,
        'footerEnabled': footerEnabled,
        'footerText': footerText,
        'stampScale': stampScale,
        'quality': quality.name,
        'cameraIndex': cameraIndex,
      };

  factory StampConfig.fromJson(Map<String, dynamic> j) {
    T byName<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.firstWhere((v) => v.name == name, orElse: () => fallback);
    const d = StampConfig();
    return StampConfig(
      titleText: j['titleText'] as String? ?? d.titleText,
      showStars: j['showStars'] as bool? ?? d.showStars,
      starCount: j['starCount'] as int? ?? d.starCount,
      showTime: j['showTime'] as bool? ?? d.showTime,
      use24h: j['use24h'] as bool? ?? d.use24h,
      showSeconds: j['showSeconds'] as bool? ?? d.showSeconds,
      showDate: j['showDate'] as bool? ?? d.showDate,
      dateStyle: byName(DateStyle.values, j['dateStyle'], d.dateStyle),
      bannerColor: j['bannerColor'] as int? ?? d.bannerColor,
      timeBoxColor: j['timeBoxColor'] as int? ?? d.timeBoxColor,
      logoPath: j['logoPath'] as String?,
      footerEnabled: j['footerEnabled'] as bool? ?? d.footerEnabled,
      footerText: j['footerText'] as String? ?? d.footerText,
      stampScale: (j['stampScale'] as num?)?.toDouble() ?? d.stampScale,
      quality: byName(CaptureQuality.values, j['quality'], d.quality),
      cameraIndex: j['cameraIndex'] as int? ?? d.cameraIndex,
    );
  }

  static Future<StampConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return const StampConfig();
    try {
      return StampConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const StampConfig();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(toJson()));
  }
}
