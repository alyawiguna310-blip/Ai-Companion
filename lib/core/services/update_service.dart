import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Result of a GitHub release check.
class UpdateInfo {
  /// e.g. "1.0.1" (tag with leading "v" stripped).
  final String latestVersion;

  /// Release title from GitHub.
  final String title;

  /// Release markdown body (release notes).
  final String notes;

  /// URL of the GitHub release page.
  final String releaseUrl;

  /// Direct APK download URL if a `.apk` asset exists.
  final String? apkUrl;

  /// When the release was published (may be null).
  final DateTime? publishedAt;

  const UpdateInfo({
    required this.latestVersion,
    required this.title,
    required this.notes,
    required this.releaseUrl,
    this.apkUrl,
    this.publishedAt,
  });
}

/// Checks the configured GitHub repo for a newer release.
///
/// The repo MUST have public releases with a semver-style tag
/// (e.g. `v1.0.1`).
class UpdateService {
  UpdateService._();

  // ============================================================
  // CONFIGURATION
  // ============================================================

  static const String owner = 'alyawiguna310-blip';
  static const String repo = 'Ai-Companion';

  // ============================================================
  // PUBLIC API
  // ============================================================

  /// Returns an [UpdateInfo] if a newer release exists,
  /// or `null` if:
  ///   • the app is already on the latest version
  ///   • the repo is not configured
  ///   • the network call failed
  static Future<UpdateInfo?> check() async {
    if (owner.isEmpty || repo.isEmpty) return null;

    try {
      final pkg = await PackageInfo.fromPlatform();
      final currentVersion = pkg.version;

      final response = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/$owner/$repo/releases/latest',
            ),
            headers: const {
              'Accept': 'application/vnd.github+json',
            },
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;

      final release = Map<String, dynamic>.from(decoded);
      final tag = release['tag_name']?.toString() ?? '';
      if (tag.isEmpty) return null;

      // Robust parser handles: v1.0.1, v.1.0.1, V 1.0.1, release-1.0.1...
      final latestVersion = _sanitizeVersion(tag);

      // If parsing failed, bail out.
      if (latestVersion.isEmpty) return null;

      // Compare using the same sanitizer on both sides, so a
      // locally-installed version like "1.0.1+2" is handled too.
      final localClean = _sanitizeVersion(currentVersion);

      if (_compare(latestVersion, localClean) <= 0) {
        return null;
      }

      return UpdateInfo(
        latestVersion: latestVersion,
        title:
            release['name']?.toString().trim().isNotEmpty == true
                ? release['name'].toString()
                : 'Version $latestVersion',
        notes: release['body']?.toString() ?? '',
        releaseUrl: release['html_url']?.toString() ?? '',
        apkUrl: _findApkAsset(release),
        publishedAt: DateTime.tryParse(
          release['published_at']?.toString() ?? '',
        ),
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // ASSET FINDER
  // ============================================================

  /// Finds a `.apk` asset in the release's [assets] array.
  static String? _findApkAsset(Map<String, dynamic> release) {
    final assets = release['assets'];
    if (assets is! List) return null;

    for (final item in assets) {
      if (item is! Map) continue;
      final name =
          item['name']?.toString().toLowerCase() ?? '';
      if (name.endsWith('.apk')) {
        return item['browser_download_url']?.toString();
      }
    }
    return null;
  }

  // ============================================================
  // VERSION SANITIZER
  // ============================================================

  /// Cleans up messy GitHub tags and app versions:
  ///
  ///   'v1.0.1'          → '1.0.1'
  ///   'v.1.0.1'         → '1.0.1'
  ///   'V 1.0.1'         → '1.0.1'
  ///   'release-1.0.1'   → '1.0.1'
  ///   '1.0.1+2'         → '1.0.1'   (build number stripped)
  ///   '1.0.1-beta'      → '1.0.1'
  static String _sanitizeVersion(String raw) {
    var v = raw.trim();

    // Strip leading letters (v, V, release-, etc.) plus any
    // separators that follow them.
    v = v.replaceFirst(
      RegExp(r'^[a-zA-Z]+[\-\.\s]*'),
      '',
    );

    // Strip any remaining leading dots/dashes/spaces.
    v = v.replaceFirst(RegExp(r'^[\.\-\s]+'), '');

    // Strip anything after '+' (build number) or '-' (pre-release tag).
    final cutIndex = v.indexOf(RegExp(r'[+\-]'));
    if (cutIndex != -1) {
      v = v.substring(0, cutIndex);
    }

    return v.trim();
  }

  // ============================================================
  // SEMVER COMPARE
  // ============================================================

  /// Semver-ish comparison. Returns:
  ///   < 0  → a older than b
  ///   = 0  → equal
  ///   > 0  → a newer than b
  static int _compare(String a, String b) {
    final aParts = _sanitizeVersion(a)
        .split('.')
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
    final bParts = _sanitizeVersion(b)
        .split('.')
        .map((p) => int.tryParse(p) ?? 0)
        .toList();

    final len = aParts.length > bParts.length
        ? aParts.length
        : bParts.length;

    for (var i = 0; i < len; i++) {
      final av = i < aParts.length ? aParts[i] : 0;
      final bv = i < bParts.length ? bParts[i] : 0;
      if (av != bv) return av - bv;
    }
    return 0;
  }
}