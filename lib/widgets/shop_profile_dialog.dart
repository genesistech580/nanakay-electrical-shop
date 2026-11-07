import 'package:flutter/material.dart';
import '../services/shop_profile.dart';

Future<void> showShopProfileDialog(BuildContext context) async {
  final profile = await ShopProfile.load();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _ShopProfileDialog(profile),
  );
}

class _ShopProfileDialog extends StatefulWidget {
  const _ShopProfileDialog(this.profile);
  final ShopProfile profile;
  @override
  State<_ShopProfileDialog> createState() => _ShopProfileDialogState();
}

class _ShopProfileDialogState extends State<_ShopProfileDialog> {
  late final _name = TextEditingController(text: widget.profile.name);
  late final _phone = TextEditingController(text: widget.profile.phone);
  late final _address = TextEditingController(text: widget.profile.address);
  late final _email = TextEditingController(text: widget.profile.email);
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    for (final controller in [_name, _phone, _address, _email]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ShopProfile(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        address: _address.text.trim(),
        email: _email.text.trim(),
      ).save();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not save shop details. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Receipt shop details'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'These details appear on customer receipts. Leave optional details blank if they do not apply.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Shop name'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter the shop name.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              enabled: !_busy,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Shop phone'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              enabled: !_busy,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Address (optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email (optional)'),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _busy ? null : _save,
        child: Text(_busy ? 'Saving...' : 'Save details'),
      ),
    ],
  );
}
