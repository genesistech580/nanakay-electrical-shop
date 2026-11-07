import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/app_control_service.dart';

const _controlInk = Color(0xFF142B49);
const _controlGreen = Color(0xFF0879E8);

class AppControlGate extends StatefulWidget {
  const AppControlGate({super.key, required this.child});
  final Widget child;

  @override
  State<AppControlGate> createState() => _AppControlGateState();
}

class _AppControlGateState extends State<AppControlGate>
    with WidgetsBindingObserver {
  late final StreamSubscription<AuthState> _authSubscription;
  AppControlSettings? _settings;
  InstalledAppInfo? _installed;
  bool _isAdmin = false;
  bool _blocked = false;
  String? _blockMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (_) => _refresh(),
    );
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_authSubscription.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final results = await Future.wait<Object>([
        AppControlService.instance.loadSettings(),
        AppControlService.instance.isCurrentUserAdmin(),
        InstalledAppInfo.load(),
      ]).timeout(const Duration(seconds: 5));
      final settings = results[0] as AppControlSettings;
      final isAdmin = results[1] as bool;
      final installed = results[2] as InstalledAppInfo;
      final blockedByService = !settings.appEnabled;
      final androidApkUpdates =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
      final blockedByVersion =
          androidApkUpdates && installed.build < settings.minimumBuild;
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _installed = installed;
        _isAdmin = isAdmin;
        _blocked = !isAdmin && (blockedByService || blockedByVersion);
        _blockMessage = blockedByService
            ? (settings.maintenanceMessage.trim().isEmpty
                  ? 'This app is temporarily unavailable. Contact the shop owner.'
                  : settings.maintenanceMessage.trim())
            : blockedByVersion
            ? 'This app version must be updated before you can continue.'
            : null;
      });
    } catch (_) {
      // Keep the locally saved shop usable if the device is offline or the
      // remote control table has not been configured yet.
    }
  }

  bool get _hasUpdate {
    final settings = _settings;
    final installed = _installed;
    return !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        settings != null &&
        installed != null &&
        settings.latestBuild > installed.build;
  }

  Uri? get _downloadUri {
    final value = _settings?.androidApkUrl.trim() ?? '';
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? uri
        : null;
  }

  Future<void> _openDownload() async {
    final uri = _downloadUri;
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_blocked) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 56,
                      color: _controlGreen,
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'App access paused',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _controlInk,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _blockMessage ?? 'Contact the app owner.',
                      textAlign: TextAlign.center,
                    ),
                    if (_hasUpdate && _downloadUri != null) ...[
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _openDownload,
                        icon: const Icon(Icons.download_outlined),
                        label: Text(
                          'Download version ${_settings!.latestVersion}',
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'After downloading, open the APK and approve the Android install prompt.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        if (!_isAdmin && _hasUpdate && _downloadUri != null)
          MaterialBanner(
            content: Text(
              'Version ${_settings!.latestVersion} is available. ${_settings!.releaseNotes}',
            ),
            leading: const Icon(Icons.system_update_alt_rounded),
            actions: [
              TextButton(onPressed: _openDownload, child: const Text('Update')),
            ],
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
