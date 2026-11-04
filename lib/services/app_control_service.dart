import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppControlSettings {
  const AppControlSettings({
    required this.appEnabled,
    required this.maintenanceMessage,
    required this.latestVersion,
    required this.latestBuild,
    required this.minimumBuild,
    required this.androidApkUrl,
    required this.releaseNotes,
    required this.updatedAt,
  });

  final bool appEnabled;
  final String maintenanceMessage;
  final String latestVersion;
  final int latestBuild;
  final int minimumBuild;
  final String androidApkUrl;
  final String releaseNotes;
  final DateTime? updatedAt;

  factory AppControlSettings.fromRow(Map<String, dynamic> row) =>
      AppControlSettings(
        appEnabled: row['app_enabled'] as bool? ?? true,
        maintenanceMessage: row['maintenance_message'] as String? ?? '',
        latestVersion: row['latest_version'] as String? ?? '1.0.0',
        latestBuild: (row['latest_build'] as num?)?.toInt() ?? 1,
        minimumBuild: (row['minimum_build'] as num?)?.toInt() ?? 1,
        androidApkUrl: row['android_apk_url'] as String? ?? '',
        releaseNotes: row['release_notes'] as String? ?? '',
        updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? ''),
      );

  Map<String, dynamic> toRow() => {
    'app_enabled': appEnabled,
    'maintenance_message': maintenanceMessage,
    'latest_version': latestVersion,
    'latest_build': latestBuild,
    'minimum_build': minimumBuild,
    'android_apk_url': androidApkUrl,
    'release_notes': releaseNotes,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };
}

class InstalledAppInfo {
  const InstalledAppInfo({required this.version, required this.build});

  final String version;
  final int build;

  static Future<InstalledAppInfo> load() async {
    final info = await PackageInfo.fromPlatform();
    return InstalledAppInfo(
      version: info.version,
      build: int.tryParse(info.buildNumber) ?? 1,
    );
  }
}

class AppControlService {
  AppControlService._();
  static final AppControlService instance = AppControlService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<bool> isCurrentUserAdmin() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final row = await _client
        .from('app_admins')
        .select('user_id')
        .eq('user_id', user.id)
        .maybeSingle();
    return row != null;
  }

  Future<AppControlSettings> loadSettings() async {
    final row = await _client.from('app_control').select().eq('id', 1).single();
    return AppControlSettings.fromRow(row);
  }

  Future<void> saveSettings(AppControlSettings settings) async {
    if (!await isCurrentUserAdmin()) {
      throw const AppControlException(
        'Only an approved app admin can save controls.',
      );
    }
    await _client
        .from('app_control')
        .update(settings.toRow())
        .eq('id', 1)
        .select('id')
        .single();
  }
}

class AppControlException implements Exception {
  const AppControlException(this.message);
  final String message;

  @override
  String toString() => message;
}
