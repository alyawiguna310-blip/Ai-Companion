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
/// Configure [owner] and [repo] below. The repo MUST have public
/// releases with a semver-style tag (e.g. `v1.0.1`).
class UpdateService {
  UpdateService._();

  // ⚠️ CHANGE THESE TO YOUR GITHUB REPO ⚠️
  static const String owner = 'alyawiguna310-blip';
  static const String repo = 'Ai-Companion';

  /// Returns an [UpdateInfo] if a newer release exists,
  /// or `null` if up to date / repo not configured / network error.
  static Future<UpdateInfo?> check() async {
    if (owner == 'YOUR_GITHUB_USERNAME' || repo == 'YOUR_REPO_NAME') {
      return null;
    }

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

      final latestVersion = tag.startsWith('v')
          ? tag.substring(1)
          : tag;

      if (_compare(latestVersion, currentVersion) <= 0) {
        return null;
      }

      return UpdateInfo(
        latestVersion: latestVersion,
        title: release['name']?.toString().trim().isNotEmpty == true
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

  /// Finds a `.apk` asset in the release's [assets] array.
  static String? _findApkAsset(Map<String, dynamic> release) {
    final assets = release['assets'];
    if (assets is! List) return null;

    for (final item in assets) {
      if (item is! Map) continue;
      final name = item['name']?.toString().toLowerCase() ?? '';
      if (name.endsWith('.apk')) {
        return item['browser_download_url']?.toString();
      }
    }
    return null;
  }

  /// Semver-ish comparison. Returns:
  ///   < 0  → a older than b
  ///   = 0  → equal
  ///   > 0  → a newer than b
  static int _compare(String a, String b) {
    final aParts = a
        .split('.')
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
    final bParts = b
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