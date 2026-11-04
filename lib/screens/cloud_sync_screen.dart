import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/shop_sync_service.dart';
import '../services/app_control_service.dart';
import 'owner_control_screen.dart';

const _ink = Color(0xFF24352F);
const _pine = Color(0xFF3D6555);
const _muted = Color(0xFF68736D);

class CloudSyncScreen extends StatefulWidget {
  const CloudSyncScreen({super.key});

  @override
  State<CloudSyncScreen> createState() => _CloudSyncScreenState();
}

class _CloudSyncScreenState extends State<CloudSyncScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _client = Supabase.instance.client;
  bool _createAccount = false;
  bool _busy = false;
  int _pending = 0;
  DateTime? _lastSync;
  String? _message;
  bool _messageIsError = false;
  bool _isAdmin = false;

  User? get _user => _client.auth.currentUser;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
    _client.auth.onAuthStateChange.listen((_) => _refreshStatus());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    final pending = await ShopSyncService.instance.pendingCount();
    final lastSync = await ShopSyncService.instance.lastSyncAt();
    var isAdmin = false;
    try {
      isAdmin = await AppControlService.instance.isCurrentUserAdmin().timeout(
        const Duration(seconds: 4),
      );
    } catch (_) {
      isAdmin = false;
    }
    if (!mounted) return;
    setState(() {
      _pending = pending;
      _lastSync = lastSync;
      _isAdmin = isAdmin;
    });
  }

  Future<void> _submitAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _message = 'Enter a valid email address.';
        _messageIsError = true;
      });
      return;
    }
    if (password.length < 8) {
      setState(() {
        _message = 'Use a password with at least 8 characters.';
        _messageIsError = true;
      });
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_createAccount) {
        final result = await _client.auth.signUp(
          email: email,
          password: password,
        );
        if (result.session == null) {
          _setMessage(
            'Account created. Check your email to confirm it, then sign in here.',
          );
        } else {
          _setMessage(
            'Account connected. Your shop records are ready to sync.',
          );
        }
      } else {
        await _client.auth.signInWithPassword(email: email, password: password);
        _setMessage('Signed in. You can sync your shop records now.');
      }
      await _refreshStatus();
    } on AuthException catch (error) {
      _setMessage(error.message, isError: true);
    } catch (_) {
      _setMessage(
        'Could not connect. Check your internet and try again.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sync() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await ShopSyncService.instance.syncNow();
      _setMessage(
        'Sync complete: ${result.uploadedEvents} change(s) sent and ${result.appliedEvents} change(s) applied.',
      );
      await _refreshStatus();
    } on ShopSyncException catch (error) {
      _setMessage(error.message, isError: true);
      await _refreshStatus();
    } on PostgrestException catch (error) {
      _setMessage(
        'Cloud sync failed: ${error.message}. Your local records are still saved; try again when connected.',
        isError: true,
      );
      await _refreshStatus();
    } on AuthException catch (error) {
      _setMessage(error.message, isError: true);
      await _refreshStatus();
    } catch (_) {
      _setMessage(
        'Could not reach the cloud. Your local records are still saved; try again when connected.',
        isError: true,
      );
      await _refreshStatus();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await _client.auth.signOut();
      _setMessage('Signed out. The shop remains available on this device.');
      await _refreshStatus();
    } catch (_) {
      _setMessage('Could not sign out. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _messageIsError = isError;
    });
  }

  String _formatLastSync(DateTime? date) {
    if (date == null) return 'Not synced yet';
    final local = date.toLocal();
    return '${local.day}/${local.month}/${local.year} at ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cloud sync',
          style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          _introCard(),
          const SizedBox(height: 16),
          if (_user == null) _signInCard() else _connectedCard(),
          if (_message != null) ...[const SizedBox(height: 12), _messageCard()],
          const SizedBox(height: 16),
          const _SyncNote(),
        ],
      ),
    );
  }

  Widget _introCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE7EEE8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.cloud_sync_outlined, color: _pine),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your shop data, backed up',
                  style: TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Products, sales, stock receipts, repayments and expenses can sync to your Supabase account.',
                  style: TextStyle(color: _muted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _signInCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _createAccount ? 'Create cloud account' : 'Sign in to sync',
            style: const TextStyle(
              color: _ink,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _createAccount
                ? 'Use an email address you can open to confirm your account.'
                : 'Use the Supabase account for this shop.',
            style: const TextStyle(color: _muted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _submitAuth,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(_createAccount ? Icons.person_add_alt_1 : Icons.login),
            label: Text(
              _busy
                  ? 'Connecting…'
                  : _createAccount
                  ? 'Create account'
                  : 'Sign in',
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _createAccount = !_createAccount;
                      _message = null;
                    }),
              child: Text(
                _createAccount
                    ? 'Already have an account? Sign in'
                    : 'New to cloud sync? Create an account',
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _connectedCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_outlined, color: _pine),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Cloud account connected',
                  style: TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Sign out',
                onPressed: _busy ? null : _signOut,
                icon: const Icon(Icons.logout_outlined),
              ),
            ],
          ),
          Text(_user?.email ?? '', style: const TextStyle(color: _muted)),
          const SizedBox(height: 18),
          _statusRow(
            'Waiting to sync',
            '$_pending ${_pending == 1 ? 'change' : 'changes'}',
          ),
          const SizedBox(height: 8),
          _statusRow('Last successful sync', _formatLastSync(_lastSync)),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy ? null : _sync,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync),
            label: Text(_busy ? 'Syncing…' : 'Sync now'),
          ),
          if (_isAdmin) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const OwnerControlScreen(),
                      ),
                    ),
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('Owner controls'),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _statusRow(String label, String value) => Row(
    children: [
      Expanded(
        child: Text(label, style: const TextStyle(color: _muted)),
      ),
      Text(
        value,
        style: const TextStyle(color: _ink, fontWeight: FontWeight.w700),
      ),
    ],
  );

  Widget _messageCard() => Card(
    color: _messageIsError ? const Color(0xFFFFF3EF) : const Color(0xFFE7EEE8),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Text(
        _message!,
        style: TextStyle(
          color: _messageIsError ? const Color(0xFF9A3412) : _ink,
        ),
      ),
    ),
  );
}

class _SyncNote extends StatelessWidget {
  const _SyncNote();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.wifi_off_outlined, color: _muted, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Offline-first: sales, stock and expenses keep saving on this device. If a sync fails, queued changes stay here for your next retry. The first successful sync also sends existing shop records.',
              style: TextStyle(color: _muted, height: 1.45),
            ),
          ),
        ],
      ),
    ),
  );
}
