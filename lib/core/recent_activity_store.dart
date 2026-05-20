import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final recentActivityStoreProvider = Provider<RecentActivityStore>((ref) {
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    webOptions: WebOptions(dbName: 'chordbase_secure', publicKey: 'chordbase'),
  );
  return const RecentActivityStore(storage);
});

final recentActivityProvider = FutureProvider.autoDispose<RecentActivity?>((
  ref,
) {
  return ref.watch(recentActivityStoreProvider).read();
});

enum RecentActivityType { chord, setlist }

class RecentActivity {
  const RecentActivity({
    required this.type,
    required this.uuid,
    required this.title,
    this.subtitle,
  });

  final RecentActivityType type;
  final String uuid;
  final String title;
  final String? subtitle;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'uuid': uuid,
    'title': title,
    'subtitle': subtitle,
  };

  factory RecentActivity.fromJson(Map<String, dynamic> json) {
    final typeName = json['type']?.toString();
    final type = RecentActivityType.values.firstWhere(
      (item) => item.name == typeName,
      orElse: () => RecentActivityType.chord,
    );
    return RecentActivity(
      type: type,
      uuid: json['uuid']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
    );
  }
}

class RecentActivityStore {
  const RecentActivityStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _key = 'chordbase.recentActivity';

  Future<RecentActivity?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final activity = RecentActivity.fromJson(json);
      if (activity.uuid.isEmpty || activity.title.isEmpty) return null;
      return activity;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(RecentActivity activity) {
    return _storage.write(key: _key, value: jsonEncode(activity.toJson()));
  }

  Future<void> clear() => _storage.delete(key: _key);
}
