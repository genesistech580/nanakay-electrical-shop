import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/app_control_service.dart';

const _ink = Color(0xFF24352F);
const _pine = Color(0xFF3D6555);
const _muted = Color(0xFF68736D);

class OwnerControlScreen extends StatefulWidget {
  const OwnerControlScreen({super.key});

  @override
  State<OwnerControlScreen> createState() => _OwnerControlScreenState();
}

class _OwnerControlScreenState extends State<OwnerControlScreen> {
  final _version = TextEditingController();
  final _latestBuild = TextEditingController();
  final _minimumBuild = TextEditingController();
  final _apkUrl = TextEditingController();
  final _releaseNotes = TextEditingController();
  final _maintenanceMessage = TextEditingController();
  bool _appEnabled = true;
  bool _loading = true;
  bool _busy = false;
  bool _isAdmin = false;
  String? _message;
  String? _error;
  InstalledAppInfo? _installed;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _version.dispose();
    _latestBuild.dispose();
    _minimumBuild.dispose();
    _apkUrl.dispose();
    _releaseNotes.dispose();
    _maintenanceMessage.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final isAdmin = await AppControlService.instance
          .isCurrentUserAdmin()
          .timeout(const Duration(seconds: 5));
      if (!isAdmin) {
        if (mounted) {
          setState(() {
            _isAdmin = false;
            _loading = false;
            _error = 'This Supabase account is not approved to manage the app.';
          });
        }
        return;
      }
      final values = await Future.wait<Object>([
        AppControlService.instance.loadSettings(),
        InstalledAppInfo.load(),
      ]).timeout(const Duration(seconds: 8));
      final settings = values[0] as AppControlSettings;
      final installed = values[1] as InstalledAppInfo;
      if (!mounted) return;
      setState(() {
        _isAdmin = true;
        _installed = installed;
        _appEnabled = settings.appEnabled;
        _version.text = settings.latestVersion;
        _latestBuild.text = settings.latestBuild.toString();
        _minimumBuild.text = settings.minimumBuild.toString();
        _apkUrl.text = settings.androidApkUrl;
        _releaseNotes.text = settings.releaseNotes;
        _maintenanceMessage.text = settings.maintenanceMessage;
        _loading = false;
      });
    } on PostgrestException catch (exception) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load app controls: ${exception.message}';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              'Could not connect to app controls. Check your internet and the Supabase setup.';
        });
      }
    }
  }

  Future<void> _save() async {
    final version = _version.text.trim();
    final latestBuild = int.tryParse(_latestBuild.text.trim());
    final minimumBuild = int.tryParse(_minimumBuild.text.trim());
    final urlText = _apkUrl.text.trim();
    final url = urlText.isEmpty ? null : Uri.tryParse(urlText);
    if (!RegExp(r'^\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.-]+)?$').hasMatch(version)) {
      setState(() => _error = 'Enter a version such as 1.2.0.');
      return;
    }
    if (latestBuild == null ||
        latestBuild < 1 ||
        minimumBuild == null ||
        minimumBuild < 1 ||
        minimumBuild > latestBuild) {
      setState(
        () => _error =
            'Build numbers must be positive, and the minimum build cannot exceed the latest build.',
      );
      return;
    }
    if (minimumBuild > 1 && urlText.isEmpty) {
      setState(
        () => _error = 'Add the HTTPS APK link before requiring a newer build.',
      );
      return;
    }
    if (urlText.isNotEmpty &&
        (url == null || url.scheme != 'https' || url.host.isEmpty)) {
      setState(() => _error = 'The APK link must be a valid HTTPS URL.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await AppControlService.instance.saveSettings(
        AppControlSettings(
          appEnabled: _appEnabled,
          maintenanceMessage: _maintenanceMessage.text.trim(),
          latestVersion: version,
          latestBuild: latestBuild,
          minimumBuild: minimumBuild,
          androidApkUrl: urlText,
          releaseNotes: _releaseNotes.text.trim(),
          updatedAt: DateTime.now(),
        ),
      );
      if (mounted) {
        setState(
          () => _message =
              'Controls saved. App installations check these settings when they next connect.',
        );
      }
    } on PostgrestException catch (exception) {
      if (mounted) {
        setState(
          () => _error = 'Could not save controls: ${exception.message}',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not save controls. Check your connection and admin access.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Owner controls',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
              children: [
                _infoCard(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _messageCard(_error!, error: true),
                ],
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  _messageCard(_message!),
                ],
                if (_isAdmin) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'App access',
                            style: TextStyle(
                              color: _ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: _appEnabled,
                            onChanged: _busy
                                ? null
                                : (value) =>
                                      setState(() => _appEnabled = value),
                            title: const Text('Allow clients to use the app'),
                            subtitle: const Text(
                              'When disabled, online non-admin installations are paused. Offline devices cannot receive the change until they reconnect.',
                            ),
                          ),
                          if (!_appEnabled) ...[
                            const SizedBox(height: 10),
                            TextField(
                              controller: _maintenanceMessage,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Message shown to clients',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Private Android updates',
                            style: TextStyle(
                              color: _ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Installed on this device: ${_installed?.version ?? 'unknown'}+${_installed?.build ?? 0}',
                            style: const TextStyle(color: _muted),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _version,
                            decoration: const InputDecoration(
                              labelText: 'Latest version',
                              hintText: '1.2.0',
                            ),
                          ),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final latest = TextField(
                                controller: _latestBuild,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Latest build',
                                ),
                              );
                              final minimum = TextField(
                                controller: _minimumBuild,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Minimum required build',
                                ),
                              );
                              return constraints.maxWidth < 520
                                  ? Column(
                                      children: [
                                        latest,
                                        const SizedBox(height: 12),
                                        minimum,
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        Expanded(child: latest),
                                        const SizedBox(width: 12),
                                        Expanded(child: minimum),
                                      ],
                                    );
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _apkUrl,
                            keyboardType: TextInputType.url,
                            decoration: const InputDecoration(
                              labelText: 'Android APK download link',
                              hintText: 'https://…',
                              helperText:
                                  'This link is shared with app installations so they can download your release.',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _releaseNotes,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'What changed in this release?',
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Build each release with the same Android signing key. Clients download the APK and approve Android’s install prompt; the app cannot silently install it.',
                            style: TextStyle(
                              color: _muted,
                              height: 1.4,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _busy ? null : _save,
                            icon: _busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(
                              _busy ? 'Saving…' : 'Save app controls',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _infoCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.admin_panel_settings_outlined, color: _pine),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isAdmin
                  ? 'Owner account: ${Supabase.instance.client.auth.currentUser?.email ?? 'signed in'}. Remote settings apply when client devices next connect.'
                  : 'Only an account approved in Supabase can use these controls. Sign in with the approved owner account and check that the Supabase migration has been applied.',
              style: const TextStyle(color: _ink, height: 1.4),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _messageCard(String message, {bool error = false}) => Card(
    color: error ? const Color(0xFFFFF3EF) : const Color(0xFFE7EEE8),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Text(
        message,
        style: TextStyle(color: error ? const Color(0xFF9A3412) : _ink),
      ),
    ),
  );
}
