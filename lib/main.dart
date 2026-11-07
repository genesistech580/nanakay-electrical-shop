import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/products_screen.dart';
import 'screens/sales_screen.dart';
import 'screens/finance_screen.dart';
import 'screens/cloud_sync_screen.dart';
import 'services/supabase_config.dart';
import 'services/shop_security_service.dart';
import 'widgets/app_control_gate.dart';
import 'theme/shop_theme.dart';

const _navy = Color(0xFF142B49);
const _blue = Color(0xFF0879E8);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseProjectUrl,
    publishableKey: supabasePublishableKey,
  );
  runApp(const ElectricalShopApp());
}

class ElectricalShopApp extends StatelessWidget {
  const ElectricalShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NanaKay Electrical Shop',
      theme: buildShopTheme(),
      home: const OwnerAccessGate(),
    );
  }
}

class OwnerAccessGate extends StatefulWidget {
  const OwnerAccessGate({super.key, this.readPin, this.writePin});

  final Future<String?> Function()? readPin;
  final Future<void> Function(String pin)? writePin;

  @override
  State<OwnerAccessGate> createState() => _OwnerAccessGateState();
}

class _OwnerAccessGateState extends State<OwnerAccessGate>
    with WidgetsBindingObserver {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = true;
  bool _setupRequired = true;
  bool _unlocked = false;
  bool _saving = false;
  bool _obscurePassword = true;
  String? _error;
  Timer? _idleTimer;
  DateTime? _lastActivityAt;
  static const _idleTimeout = Duration(minutes: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointerEvent);
    _loadAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointerEvent);
    _idleTimer?.cancel();
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _loadAccess() async {
    try {
      if (widget.readPin != null) {
        final pin = await widget.readPin!();
        if (mounted) {
          setState(() {
            _setupRequired = pin == null;
            _loading = false;
          });
        }
        return;
      }

      final needed = await ShopSecurityService.instance.isSetupRequired();
      if (mounted) {
        setState(() {
          _setupRequired = needed;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _setupRequired = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    final pin = _pinController.text.trim();
    if (pin.length < 4) {
      setState(
        () => _error = 'Enter at least 4 characters for your password / PIN.',
      );
      return;
    }
    if (_setupRequired && pin != _confirmController.text.trim()) {
      setState(() => _error = 'The passwords do not match.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_setupRequired) {
        if (widget.writePin != null) {
          await widget.writePin!(pin);
        } else {
          await ShopSecurityService.instance.savePassword(pin);
        }
      } else {
        bool isValid = false;
        if (widget.readPin != null) {
          final savedPin = await widget.readPin!();
          isValid = savedPin == pin;
        } else {
          isValid = await ShopSecurityService.instance.verifyPassword(pin);
        }
        if (!isValid) {
          throw const FormatException('Incorrect password / PIN. Try again.');
        }
      }
      if (mounted) {
        setState(() {
          _unlocked = true;
          _saving = false;
        });
        _recordActivity();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is FormatException
              ? error.message
              : 'Could not save or verify the owner password.';
          _saving = false;
        });
      }
    }
  }

  void _onPointerEvent(PointerEvent event) {
    if (event is PointerDownEvent || event is PointerMoveEvent) {
      _recordActivity();
    }
  }

  void _recordActivity() {
    if (!_unlocked) return;
    _lastActivityAt = DateTime.now();
    _scheduleIdleLock(_idleTimeout);
  }

  void _scheduleIdleLock(Duration delay) {
    _idleTimer?.cancel();
    _idleTimer = Timer(delay, _lockForInactivity);
  }

  void _lockForInactivity() {
    if (!mounted || !_unlocked) return;
    setState(() {
      _unlocked = false;
      _pinController.clear();
      _confirmController.clear();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_unlocked) return;
    final lastActivity = _lastActivityAt;
    if (lastActivity == null) {
      _recordActivity();
      return;
    }
    final remaining = _idleTimeout - DateTime.now().difference(lastActivity);
    if (remaining <= Duration.zero) {
      _lockForInactivity();
    } else {
      _scheduleIdleLock(remaining);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_unlocked) {
      return Focus(
        onKeyEvent: (_, _) {
          _recordActivity();
          return KeyEventResult.ignored;
        },
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _recordActivity(),
          onPointerMove: (_) => _recordActivity(),
          onPointerSignal: (_) => _recordActivity(),
          child: const AppControlGate(child: ShopDashboard()),
        ),
      );
    }
    return Scaffold(
      bottomNavigationBar: const _DeveloperCredit(dark: true),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0784F6), Color(0xFF075DC4)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Image.asset('assets/brand/nanakay_mark_light.png'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'NANAKAY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'ELECTRICAL SHOP',
                    style: TextStyle(
                      color: Color(0xFFDCEBFF),
                      fontSize: 11,
                      letterSpacing: 2.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _setupRequired
                                ? 'Set up owner access'
                                : 'Welcome back',
                            style: const TextStyle(
                              color: _navy,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _setupRequired
                                ? 'Create a secure password or PIN to protect this shop.'
                                : 'Enter your owner password or PIN to continue.',
                            style: const TextStyle(color: Color(0xFF647891)),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _pinController,
                            obscureText: _obscurePassword,
                            keyboardType: TextInputType.visiblePassword,
                            decoration: InputDecoration(
                              labelText: 'Password / PIN',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                          ),
                          if (_setupRequired) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: _confirmController,
                              obscureText: _obscurePassword,
                              keyboardType: TextInputType.visiblePassword,
                              decoration: const InputDecoration(
                                labelText: 'Confirm Password / PIN',
                                prefixIcon: Icon(Icons.verified_user_outlined),
                              ),
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: const TextStyle(color: Color(0xFFB42318)),
                            ),
                          ],
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed: _saving ? null : _submit,
                            child: Text(
                              _saving
                                  ? 'Please wait…'
                                  : _setupRequired
                                  ? 'Create PIN and continue'
                                  : 'Unlock shop',
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Your password is saved securely in your database and encrypted on this device.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF647891),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ShopDashboard extends StatefulWidget {
  const ShopDashboard({super.key});

  @override
  State<ShopDashboard> createState() => _ShopDashboardState();
}

class _ShopDashboardState extends State<ShopDashboard> {
  int _selectedIndex = 0;

  void _selectPage(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _OverviewScreen(onOpenProducts: () => _selectPage(1)),
      const ProductsScreen(),
      const SalesScreen(),
      const FinanceScreen(),
      const CloudSyncScreen(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                if (wide)
                  NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: _selectPage,
                    labelType: NavigationRailLabelType.all,
                    backgroundColor: const Color(0xFFFFFFFF),
                    leading: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: _BrandMark(compact: true),
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.space_dashboard_outlined),
                        selectedIcon: Icon(Icons.space_dashboard_rounded),
                        label: Text('Overview'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.inventory_2_outlined),
                        selectedIcon: Icon(Icons.inventory_2_rounded),
                        label: Text('Products'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.point_of_sale_outlined),
                        selectedIcon: Icon(Icons.point_of_sale_rounded),
                        label: Text('Sales'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.account_balance_wallet_outlined),
                        selectedIcon: Icon(Icons.account_balance_wallet),
                        label: Text('Finances'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.cloud_sync_outlined),
                        selectedIcon: Icon(Icons.cloud_sync_rounded),
                        label: Text('Sync'),
                      ),
                    ],
                  ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: IndexedStack(
                          index: _selectedIndex,
                          children: pages,
                        ),
                      ),
                      const _DeveloperCredit(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _selectPage,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.space_dashboard_outlined),
                      selectedIcon: Icon(Icons.space_dashboard_rounded),
                      label: 'Overview',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2_rounded),
                      label: 'Products',
                    ),
                    NavigationDestination(
                      icon: _SalesNavigationIcon(),
                      selectedIcon: _SalesNavigationIcon(),
                      label: 'Sales',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.account_balance_wallet_outlined),
                      selectedIcon: Icon(Icons.account_balance_wallet),
                      label: 'Finances',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.cloud_sync_outlined),
                      selectedIcon: Icon(Icons.cloud_sync_rounded),
                      label: 'Sync',
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _DeveloperCredit extends StatelessWidget {
  const _DeveloperCredit({this.dark = false});

  final bool dark;

  @override
  Widget build(BuildContext context) => Container(
    height: 34,
    width: double.infinity,
    decoration: BoxDecoration(
      color: dark ? _navy : const Color(0xFFFFFFFF),
      border: Border(
        top: BorderSide(
          color: dark ? const Color(0xFF275B96) : const Color(0xFFE4ECF5),
        ),
      ),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.bolt_rounded, size: 13, color: Color(0xFFB67C3D)),
        const SizedBox(width: 5),
        Text(
          '© Developed by Genesis Tech',
          style: TextStyle(
            color: dark ? const Color(0xFFDCEBFF) : const Color(0xFF647891),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ],
    ),
  );
}

class _OverviewScreen extends StatefulWidget {
  const _OverviewScreen({required this.onOpenProducts});

  final VoidCallback onOpenProducts;

  @override
  State<_OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<_OverviewScreen> {
  static const _productsKey = 'electrical_shop_products_v1';
  static const _salesKey = 'electrical_shop_sales_v1';
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _sales = [];

  @override
  void initState() {
    super.initState();
    productStockChanged.addListener(_loadOverview);
    _loadOverview();
  }

  @override
  void dispose() {
    productStockChanged.removeListener(_loadOverview);
    super.dispose();
  }

  Future<void> _loadOverview() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final productData = prefs.getString(_productsKey);
      final salesData = prefs.getString(_salesKey);
      final products = productData == null
          ? <Map<String, dynamic>>[]
          : (jsonDecode(productData) as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
      final sales = salesData == null
          ? <Map<String, dynamic>>[]
          : (jsonDecode(salesData) as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
      if (mounted) {
        setState(() {
          _products = products;
          _sales = sales;
        });
      }
    } catch (_) {
      // Keep the last successfully loaded overview visible if saved data is invalid.
    }
  }

  String _money(double value) => 'GHS ${value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final lowStock = _products
        .where(
          (p) =>
              (p['quantity'] as num? ?? 0) <= (p['lowStockLimit'] as num? ?? 0),
        )
        .toList();
    final units = _products.fold<int>(
      0,
      (sum, p) => sum + ((p['quantity'] as num?)?.toInt() ?? 0),
    );
    final now = DateTime.now();
    final todaysSales = _sales.where((s) {
      final date = DateTime.tryParse(s['date'] as String? ?? '')?.toLocal();
      return date != null &&
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList();
    final salesTotal = todaysSales.fold<double>(
      0,
      (sum, s) => sum + ((s['total'] as num?)?.toDouble() ?? 0),
    );
    final profit = todaysSales.fold<double>(0, (sum, s) {
      final items = s['items'] as List<dynamic>? ?? const [];
      return sum +
          items.fold<double>(0, (itemSum, raw) {
            final item = Map<String, dynamic>.from(raw as Map);
            final savedCost = item['unitCost'];
            if (savedCost is! num) return itemSum;
            final cost = savedCost.toDouble();
            final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
            final price = (item['unitPrice'] as num?)?.toDouble() ?? 0;
            return itemSum + (price - cost) * quantity;
          });
    });
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _blue,
        toolbarHeight: 86,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: const _BrandMark(onBlue: true),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: CircleAvatar(
              backgroundColor: const Color(0xFFE8F7EF),
              foregroundColor: _blue,
              child: Image.asset(
                'assets/brand/nanakay_mark_dark.png',
                width: 25,
                height: 25,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
        children: [
          Text(
            'Shop overview',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: _navy,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'A clear view of your electrical shop.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF647891)),
          ),
          const SizedBox(height: 24),
          Card(
            color: _blue,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 480;
                  final copy = const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Keep your inventory up to date',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Add products, update prices and check stock levels.',
                        style: TextStyle(color: Color(0xFFDCEBFF)),
                      ),
                    ],
                  );
                  final button = FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _blue,
                    ),
                    onPressed: widget.onOpenProducts,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Open products'),
                  );
                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [copy, const SizedBox(height: 16), button],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: copy),
                      const SizedBox(width: 16),
                      button,
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 850
                  ? 4
                  : constraints.maxWidth >= 300
                  ? 2
                  : 1;
              const gap = 14.0;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                    width: width,
                    child: _MetricCard(
                      label: "Today's sales",
                      value: _money(salesTotal),
                      helper: '${todaysSales.length} recorded sales today',
                      icon: Icons.payments_outlined,
                      tint: Color(0xFFE9F3FF),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _MetricCard(
                      label: 'Estimated profit',
                      value: _money(profit),
                      helper: 'Recorded where a sale has saved cost data',
                      icon: Icons.trending_up_rounded,
                      tint: Color(0xFFE8F7EF),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _MetricCard(
                      label: 'Units in stock',
                      value: '$units',
                      helper: '${_products.length} product types',
                      icon: Icons.inventory_2_outlined,
                      tint: Color(0xFFFFF3DF),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _MetricCard(
                      label: 'Low-stock products',
                      value: '${lowStock.length}',
                      helper: lowStock.isEmpty
                          ? 'All products above limits'
                          : 'Needs a stock check',
                      icon: Icons.warning_amber_rounded,
                      tint: Color(0xFFFFEAEA),
                    ),
                  ),
                ],
              );
            },
          ),
          if (lowStock.isNotEmpty) ...[
            const SizedBox(height: 18),
            Card(
              color: const Color(0xFFFFF6E8),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFB54708),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${lowStock.length} low-stock ${lowStock.length == 1 ? 'product' : 'products'}',
                            style: const TextStyle(
                              color: Color(0xFF7A2E0E),
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: widget.onOpenProducts,
                          child: const Text('Review stock'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      lowStock
                          .take(5)
                          .map(
                            (p) =>
                                '${p['name']}: ${p['quantity']} left (limit ${p['lowStockLimit']})',
                          )
                          .join('  ·  '),
                      style: const TextStyle(color: Color(0xFF7A2E0E)),
                    ),
                    if (lowStock.length > 5)
                      Text(
                        'and ${lowStock.length - 5} more',
                        style: const TextStyle(color: Color(0xFF7A2E0E)),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const _InfoNote(
            icon: Icons.info_outline_rounded,
            text:
                'Sales, inventory counts and low-stock alerts update from saved shop records.',
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.compact = false, this.onBlue = false});
  final bool compact;
  final bool onBlue;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: onBlue ? Colors.white.withValues(alpha: .2) : _blue,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(8),
        child: Image.asset('assets/brand/nanakay_mark_light.png'),
      ),
      if (!compact) ...[
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'NanaKay Electrical Shop',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: onBlue ? Colors.white : _navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ELECTRICAL SHOP',
                style: TextStyle(
                  color: onBlue
                      ? const Color(0xFFDCEBFF)
                      : const Color(0xFF718299),
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.helper,
    required this.icon,
    required this.tint,
  });

  final String label;
  final String value;
  final String helper;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final accent = tint == const Color(0xFFFFEAEA)
        ? const Color(0xFFDC454B)
        : tint == const Color(0xFFFFF3DF)
        ? const Color(0xFFE1A400)
        : tint == const Color(0xFFE8F7EF)
        ? const Color(0xFF08A26D)
        : _blue;
    return Card(
      color: tint,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: .15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, size: 24, color: Colors.white),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: Center(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 32,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 30,
              child: Text(
                helper,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF647891),
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 17,
          color: Color(0xFF647891),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFF647891), fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _SalesNavigationIcon extends StatelessWidget {
  const _SalesNavigationIcon();
  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: _blue,
      boxShadow: [
        BoxShadow(
          color: _blue.withValues(alpha: .23),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: const Icon(
      Icons.point_of_sale_rounded,
      color: Colors.white,
      size: 23,
    ),
  );
}
