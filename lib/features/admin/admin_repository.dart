import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(apiClientProvider));
});

final adminUsersProvider = FutureProvider.autoDispose<List<AdminUser>>((ref) {
  return ref.watch(adminRepositoryProvider).listUsers();
});

class AdminRepository {
  const AdminRepository(this._api);

  final ApiClient _api;

  Future<List<AdminUser>> listUsers() async {
    final response = await _api.get<List<dynamic>>('/admin/users');
    return (response.data ?? const [])
        .map((item) => AdminUser.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AdminUser> setAdmin(AdminUser user, bool enabled) async {
    final roles = <String>{
      ...user.roles.where((role) => role != 'ROLE_ADMIN'),
      if (enabled) 'ROLE_ADMIN',
      if (!user.roles.contains('ROLE_USER')) 'ROLE_USER',
    }.toList();
    final response = await _api.put<Map<String, dynamic>>(
      '/admin/users/${user.uuid}/roles',
      data: {'roles': roles},
    );
    return AdminUser.fromJson(response.data!);
  }

  Future<AdminUser> setRoles(AdminUser user, List<String> roles) async {
    final normalized = roles.isEmpty ? ['ROLE_USER'] : roles;
    final response = await _api.put<Map<String, dynamic>>(
      '/admin/users/${user.uuid}/roles',
      data: {'roles': normalized},
    );
    return AdminUser.fromJson(response.data!);
  }

  Future<AdminUser> setActive(AdminUser user, bool active) async {
    final response = await _api.put<Map<String, dynamic>>(
      '/admin/users/${user.uuid}/active',
      data: {'active': active},
    );
    return AdminUser.fromJson(response.data!);
  }

  Future<List<ChordSummary>> userChords(String userUuid) async {
    final response = await _api.get<List<dynamic>>(
      '/admin/users/$userUuid/chords',
    );
    return (response.data ?? const [])
        .map((item) => ChordSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Setlist>> userSetlists(String userUuid) async {
    final response = await _api.get<List<dynamic>>(
      '/admin/users/$userUuid/setlists',
    );
    return (response.data ?? const [])
        .map((item) => Setlist.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

final adminUserChordsProvider = FutureProvider.autoDispose
    .family<List<ChordSummary>, String>((ref, uuid) {
      return ref.watch(adminRepositoryProvider).userChords(uuid);
    });

final adminUserSetlistsProvider = FutureProvider.autoDispose
    .family<List<Setlist>, String>((ref, uuid) {
      return ref.watch(adminRepositoryProvider).userSetlists(uuid);
    });
