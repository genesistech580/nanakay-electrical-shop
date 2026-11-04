import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/products_screen.dart';

const _queueKey = 'electrical_shop_sync_queue_v1';
const _baselineKey = 'electrical_shop_sync_baseline_v1';
const _deviceKey = 'electrical_shop_sync_device_v1';
const _ownerKey = 'electrical_shop_sync_owner_v1';
const _lastSyncKey = 'electrical_shop_last_sync_v1';

const _dataSets = <_DataSet>[
  _DataSet('product', 'electrical_shop_products_v1'),
  _DataSet('sale', 'electrical_shop_sales_v1'),
  _DataSet('stock_receipt', 'electrical_shop_stock_receipts_v1'),
  _DataSet('repayment', 'electrical_shop_repayments_v1'),
  _DataSet('expense', 'electrical_shop_expenses_v1'),
];

class _DataSet {
  const _DataSet(this.entityType, this.storageKey);
  final String entityType;
  final String storageKey;
}

class ShopSyncResult {
  const ShopSyncResult({
    required this.uploadedEvents,
    required this.appliedEvents,
    required this.pendingEvents,
    required this.completedAt,
  });

  final int uploadedEvents;
  final int appliedEvents;
  final int pendingEvents;
  final DateTime completedAt;
}

class ShopSyncService {
  ShopSyncService._();
  static final ShopSyncService instance = ShopSyncService._();
  SupabaseClient get _client => Supabase.instance.client;

  Future<int> pendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = _decodeMapList(prefs.getString(_queueKey));
    final queuedKeys = {
      for (final event in queue)
        '${event['entity_type']}\u0000${event['entity_id']}',
    };
    final baseline = _decodeBaseline(prefs.getString(_baselineKey));
    var count = queue.length;
    for (final dataSet in _dataSets) {
      final current = _readLocalRecords(prefs, dataSet.storageKey);
      final currentIds = <String>{};
      final previous = baseline[dataSet.entityType] ?? const <String, String>{};
      for (final record in current) {
        final id = record['id']?.toString();
        if (id == null || id.isEmpty) continue;
        currentIds.add(id);
        final key = '${dataSet.entityType}\u0000$id';
        if (previous[id] != jsonEncode(record) && !queuedKeys.contains(key)) {
          count++;
        }
      }
      for (final oldId in previous.keys) {
        final key = '${dataSet.entityType}\u0000$oldId';
        if (!currentIds.contains(oldId) && !queuedKeys.contains(key)) count++;
      }
    }
    return count;
  }

  Future<DateTime?> lastSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_lastSyncKey);
    return value == null ? null : DateTime.tryParse(value)?.toLocal();
  }

  Future<ShopSyncResult> syncNow() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const ShopSyncException(
        'Sign in to a Supabase account before syncing this shop.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final boundOwner = prefs.getString(_ownerKey);
    if (boundOwner != null && boundOwner != user.id) {
      throw const ShopSyncException(
        'This device is linked to a different Supabase account. Sign back into that account to sync.',
      );
    }
    if (boundOwner == null && !await prefs.setString(_ownerKey, user.id)) {
      throw const ShopSyncException(
        'Could not save the shop account on this device.',
      );
    }

    final deviceId = await _getDeviceId(prefs);
    final queue = _decodeMapList(prefs.getString(_queueKey));
    final baseline = _decodeBaseline(prefs.getString(_baselineKey));
    _queueLocalChanges(prefs, queue, baseline, deviceId);
    await _saveJson(prefs, _queueKey, queue);
    await _saveJson(prefs, _baselineKey, baseline);
    final uploadCount = queue.length;

    if (queue.isNotEmpty) {
      const batchSize = 100;
      for (var start = 0; start < queue.length; start += batchSize) {
        final end = min(start + batchSize, queue.length);
        final rows = queue
            .sublist(start, end)
            .map((event) => <String, dynamic>{...event, 'owner_id': user.id})
            .toList();
        await _client
            .from('shop_sync_events')
            .upsert(rows, onConflict: 'id', ignoreDuplicates: true);
      }
      queue.clear();
      await _saveJson(prefs, _queueKey, queue);
    }

    final remoteEvents = await _loadRemoteEvents(user.id);
    final applied = await _applyRemoteEvents(prefs, remoteEvents, baseline);
    await _saveJson(prefs, _baselineKey, baseline);

    final completedAt = DateTime.now();
    if (!await prefs.setString(
      _lastSyncKey,
      completedAt.toUtc().toIso8601String(),
    )) {
      throw const ShopSyncException(
        'The shop synced, but the sync time could not be saved.',
      );
    }
    if (applied > 0) productStockChanged.value++;

    return ShopSyncResult(
      uploadedEvents: uploadCount,
      appliedEvents: applied,
      pendingEvents: queue.length,
      completedAt: completedAt,
    );
  }

  int _queueLocalChanges(
    SharedPreferences prefs,
    List<Map<String, dynamic>> queue,
    Map<String, Map<String, String>> baseline,
    String deviceId,
  ) {
    var added = 0;
    for (final dataSet in _dataSets) {
      final current = _readLocalRecords(prefs, dataSet.storageKey);
      final previous = baseline.putIfAbsent(dataSet.entityType, () => {});
      final currentIds = <String>{};

      for (final record in current) {
        final id = record['id']?.toString();
        if (id == null || id.isEmpty) continue;
        currentIds.add(id);
        final encoded = jsonEncode(record);
        if (previous[id] == encoded) continue;
        queue.removeWhere(
          (event) =>
              event['entity_type'] == dataSet.entityType &&
              event['entity_id'] == id,
        );
        queue.add(
          _newEvent(
            deviceId: deviceId,
            entityType: dataSet.entityType,
            entityId: id,
            operation: 'upsert',
            payload: record,
          ),
        );
        previous[id] = encoded;
        added++;
      }

      for (final oldId in previous.keys.toList()) {
        if (currentIds.contains(oldId)) continue;
        queue.removeWhere(
          (event) =>
              event['entity_type'] == dataSet.entityType &&
              event['entity_id'] == oldId,
        );
        queue.add(
          _newEvent(
            deviceId: deviceId,
            entityType: dataSet.entityType,
            entityId: oldId,
            operation: 'delete',
            payload: const <String, dynamic>{},
          ),
        );
        previous.remove(oldId);
        added++;
      }
    }
    return added;
  }

  Future<List<Map<String, dynamic>>> _loadRemoteEvents(String ownerId) async {
    const pageSize = 500;
    final events = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final page = await _client
          .from('shop_sync_events')
          .select(
            'entity_type,entity_id,operation,payload,occurred_at,received_at',
          )
          .eq('owner_id', ownerId)
          .order('occurred_at')
          .range(offset, offset + pageSize - 1);
      events.addAll(page.map((row) => Map<String, dynamic>.from(row)));
      if (page.length < pageSize) break;
      offset += pageSize;
    }
    return events;
  }

  Future<int> _applyRemoteEvents(
    SharedPreferences prefs,
    List<Map<String, dynamic>> events,
    Map<String, Map<String, String>> baseline,
  ) async {
    events.sort((a, b) {
      final aTime =
          DateTime.tryParse(a['occurred_at'] as String? ?? '') ??
          DateTime(1970);
      final bTime =
          DateTime.tryParse(b['occurred_at'] as String? ?? '') ??
          DateTime(1970);
      final byTime = aTime.compareTo(bTime);
      if (byTime != 0) return byTime;
      return (a['received_at'] as String? ?? '').compareTo(
        b['received_at'] as String? ?? '',
      );
    });

    final recordsByType = <String, Map<String, Map<String, dynamic>>>{};
    for (final dataSet in _dataSets) {
      recordsByType[dataSet.entityType] = {
        for (final record in _readLocalRecords(prefs, dataSet.storageKey))
          if (record['id'] != null) record['id'].toString(): record,
      };
    }

    var applied = 0;
    for (final event in events) {
      final type = event['entity_type'] as String?;
      final id = event['entity_id']?.toString();
      final records = recordsByType[type];
      if (records == null || id == null || id.isEmpty) continue;
      if (event['operation'] == 'delete') {
        if (records.remove(id) != null) applied++;
      } else if (event['operation'] == 'upsert') {
        final rawPayload = event['payload'];
        if (rawPayload is! Map) continue;
        final payload = Map<String, dynamic>.from(rawPayload);
        if (payload['id']?.toString() != id) continue;
        final prior = records[id];
        if (prior == null || jsonEncode(prior) != jsonEncode(payload)) {
          applied++;
        }
        records[id] = payload;
      }
    }

    for (final dataSet in _dataSets) {
      final records = recordsByType[dataSet.entityType]!;
      final list = records.values.toList();
      final encoded = jsonEncode(list);
      final currentRaw = prefs.getString(dataSet.storageKey);
      final current = currentRaw == null
          ? <Map<String, dynamic>>[]
          : _decodeMapList(currentRaw);
      if (jsonEncode(current) != encoded &&
          !await prefs.setString(dataSet.storageKey, encoded)) {
        throw ShopSyncException(
          'Could not save synced ${dataSet.entityType} records on this device.',
        );
      }
      baseline[dataSet.entityType] = {
        for (final record in list)
          if (record['id'] != null) record['id'].toString(): jsonEncode(record),
      };
    }
    return applied;
  }

  List<Map<String, dynamic>> _readLocalRecords(
    SharedPreferences prefs,
    String key,
  ) {
    final raw = prefs.getString(key);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } on FormatException {
      return [];
    }
  }

  List<Map<String, dynamic>> _decodeMapList(String? raw) {
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } on FormatException {
      return [];
    }
  }

  Map<String, Map<String, String>> _decodeBaseline(String? raw) {
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries)
          if (entry.value is Map)
            entry.key.toString(): {
              for (final row in (entry.value as Map).entries)
                row.key.toString(): row.value.toString(),
            },
      };
    } on FormatException {
      return {};
    }
  }

  Map<String, dynamic> _newEvent({
    required String deviceId,
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) => {
    'id': _uuidV4(),
    'device_id': deviceId,
    'entity_type': entityType,
    'entity_id': entityId,
    'operation': operation,
    'payload': payload,
    'occurred_at': DateTime.now().toUtc().toIso8601String(),
  };

  Future<String> _getDeviceId(SharedPreferences prefs) async {
    final existing = prefs.getString(_deviceKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = _uuidV4();
    if (!await prefs.setString(_deviceKey, created)) {
      throw const ShopSyncException('Could not create a local device ID.');
    }
    return created;
  }

  Future<void> _saveJson(
    SharedPreferences prefs,
    String key,
    Object value,
  ) async {
    if (!await prefs.setString(key, jsonEncode(value))) {
      throw const ShopSyncException('Could not save the offline sync queue.');
    }
  }

  String _uuidV4() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}

class ShopSyncException implements Exception {
  const ShopSyncException(this.message);
  final String message;
  @override
  String toString() => message;
}
