import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';

final setlistsRepositoryProvider = Provider<SetlistsRepository>((ref) {
  return SetlistsRepository(ref.watch(apiClientProvider));
});

class SetlistsRepository {
  SetlistsRepository(this._api);

  final ApiClient _api;

  Future<List<Setlist>> mine() async {
    final response = await _api.get<List<dynamic>>('/setlists/me');
    return (response.data ?? const [])
        .map((item) => Setlist.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Setlist> getById(String uuid) async {
    final response = await _api.get<Map<String, dynamic>>('/setlists/$uuid');
    return Setlist.fromJson(response.data!);
  }

  Future<Setlist> create({
    required String name,
    required String visibility,
    String? description,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/setlists',
      data: {
        'name': name,
        'description': description,
        'visibility': visibility,
      },
    );
    return Setlist.fromJson(response.data!);
  }

  Future<Setlist> update(Setlist setlist) async {
    return updateDetails(
      uuid: setlist.uuid,
      name: setlist.name,
      description: setlist.description,
      visibility: setlist.visibility,
    );
  }

  Future<Setlist> updateDetails({
    required String uuid,
    required String name,
    required String visibility,
    String? description,
  }) async {
    final response = await _api.put<Map<String, dynamic>>(
      '/setlists/$uuid',
      data: {
        'name': name,
        'description': description,
        'visibility': visibility,
      },
    );
    return Setlist.fromJson(response.data!);
  }

  Future<void> delete(String uuid) => _api.delete<void>('/setlists/$uuid');

  Future<Setlist> addChord(String setlistUuid, String chordUuid) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/setlists/$setlistUuid/chords/$chordUuid',
    );
    return Setlist.fromJson(response.data!);
  }

  Future<Setlist> removeChord(String setlistUuid, String chordUuid) async {
    final response = await _api.delete<Map<String, dynamic>>(
      '/setlists/$setlistUuid/chords/$chordUuid',
    );
    return Setlist.fromJson(response.data!);
  }

  Future<Setlist> reorder(String setlistUuid, List<SetlistChord> chords) async {
    final response = await _api.put<Map<String, dynamic>>(
      '/setlists/$setlistUuid/chords/reorder',
      data: {
        'chords': [
          for (var i = 0; i < chords.length; i++)
            {'chordUuid': chords[i].uuid, 'position': i + 1},
        ],
      },
    );
    return Setlist.fromJson(response.data!);
  }

  Future<List<SetlistInvite>> invites() async {
    final response = await _api.get<List<dynamic>>(
      '/setlists/collaborator-invites/me',
    );
    return (response.data ?? const [])
        .map((item) => SetlistInvite.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> acceptInvite(String inviteUuid) =>
      _api.post<void>('/setlists/collaborator-invites/$inviteUuid/accept');

  Future<void> declineInvite(String inviteUuid) =>
      _api.post<void>('/setlists/collaborator-invites/$inviteUuid/decline');

  Future<List<UserSearchResult>> searchUsers(String userName) async {
    if (userName.trim().isEmpty) return const [];
    final response = await _api.get<List<dynamic>>(
      '/users/search',
      queryParameters: {'userName': userName.trim()},
    );
    return (response.data ?? const [])
        .map((item) => UserSearchResult.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Setlist> inviteCollaborator(
    String setlistUuid,
    String userUuid,
  ) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/setlists/$setlistUuid/collaborator-invites',
      data: {'userUuid': userUuid},
    );
    return Setlist.fromJson(response.data!);
  }

  Future<Setlist> removeCollaborator(
    String setlistUuid,
    String userUuid,
  ) async {
    final response = await _api.delete<Map<String, dynamic>>(
      '/setlists/$setlistUuid/collaborators/$userUuid',
    );
    return Setlist.fromJson(response.data!);
  }
}
