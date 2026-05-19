class UserProfile {
  const UserProfile({
    required this.uuid,
    required this.userName,
    required this.email,
    required this.roles,
    this.active = true,
    this.profileImageUrl,
  });

  final String uuid;
  final String userName;
  final String email;
  final String? profileImageUrl;
  final List<String> roles;
  final bool active;

  bool get isAdmin => roles.contains('ROLE_ADMIN');

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    uuid: jsonText(json, 'uuid'),
    userName: jsonText(json, 'userName'),
    email: jsonText(json, 'email'),
    profileImageUrl: jsonNullableText(json, 'profileImageUrl'),
    roles: jsonStringList(json, 'roles'),
    active: jsonBool(json, 'active', fallback: true),
  );
}

class AdminUser {
  const AdminUser({
    required this.uuid,
    required this.userName,
    required this.email,
    required this.roles,
    required this.active,
    this.profileImageUrl,
  });

  final String uuid;
  final String userName;
  final String email;
  final String? profileImageUrl;
  final List<String> roles;
  final bool active;

  bool get isAdmin => roles.contains('ROLE_ADMIN');

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
    uuid: jsonText(json, 'uuid'),
    userName: jsonText(json, 'userName'),
    email: jsonText(json, 'email'),
    profileImageUrl: jsonNullableText(json, 'profileImageUrl'),
    roles: jsonStringList(json, 'roles'),
    active: jsonBool(json, 'active', fallback: true),
  );
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final UserProfile user;
}

class ChordSummary {
  const ChordSummary({
    required this.uuid,
    required this.chordName,
    required this.artist,
    required this.addBy,
    required this.status,
  });

  final String uuid;
  final String chordName;
  final String artist;
  final String addBy;
  final String status;

  bool get isPublished => status == 'PUBLISHED';

  factory ChordSummary.fromJson(Map<String, dynamic> json) => ChordSummary(
    uuid: jsonText(json, 'uuid'),
    chordName: jsonText(json, 'chordName'),
    artist: jsonText(json, 'artist', fallback: 'Nao informado'),
    addBy: jsonText(json, 'addBy'),
    status: jsonText(json, 'status', fallback: 'PUBLISHED'),
  );
}

class ChordDetail {
  const ChordDetail({
    required this.uuid,
    required this.chordName,
    required this.artist,
    required this.chordPro,
    required this.addBy,
  });

  final String uuid;
  final String chordName;
  final String artist;
  final String chordPro;
  final String addBy;

  factory ChordDetail.fromJson(Map<String, dynamic> json) => ChordDetail(
    uuid: jsonText(json, 'uuid'),
    chordName: jsonText(json, 'chordName'),
    artist: jsonText(json, 'artist', fallback: 'Nao informado'),
    chordPro: jsonText(json, 'chordPro'),
    addBy: jsonText(json, 'addBy'),
  );
}

class ChordPreview {
  const ChordPreview({
    required this.uuid,
    required this.chordName,
    required this.artist,
    required this.chordPro,
    required this.status,
  });

  final String uuid;
  final String chordName;
  final String artist;
  final String chordPro;
  final String status;

  factory ChordPreview.fromJson(Map<String, dynamic> json) => ChordPreview(
    uuid: jsonText(json, 'uuid'),
    chordName: jsonText(json, 'chordName'),
    artist: jsonText(json, 'artist', fallback: 'Nao informado'),
    chordPro: jsonText(json, 'chordPro'),
    status: jsonText(json, 'status', fallback: 'DRAFT'),
  );
}

class Setlist {
  const Setlist({
    required this.uuid,
    required this.name,
    required this.visibility,
    required this.ownerUuid,
    required this.ownerUserName,
    required this.chords,
    required this.collaborators,
    this.description,
  });

  final String uuid;
  final String name;
  final String? description;
  final String visibility;
  final String ownerUuid;
  final String ownerUserName;
  final List<SetlistChord> chords;
  final List<SetlistCollaborator> collaborators;

  factory Setlist.fromJson(Map<String, dynamic> json) => Setlist(
    uuid: jsonText(json, 'uuid'),
    name: jsonText(json, 'name'),
    description: jsonNullableText(json, 'description'),
    visibility: jsonText(json, 'visibility', fallback: 'PRIVATE'),
    ownerUuid: jsonText(json, 'ownerUuid'),
    ownerUserName: jsonText(json, 'ownerUserName'),
    chords: (json['chords'] as List<dynamic>? ?? const [])
        .map((item) => SetlistChord.fromJson(item as Map<String, dynamic>))
        .toList(),
    collaborators: (json['collaborators'] as List<dynamic>? ?? const [])
        .map(
          (item) => SetlistCollaborator.fromJson(item as Map<String, dynamic>),
        )
        .toList(),
  );
}

class SetlistChord {
  const SetlistChord({
    required this.uuid,
    required this.chordName,
    required this.artist,
    required this.addBy,
    required this.position,
  });

  final String uuid;
  final String chordName;
  final String artist;
  final String addBy;
  final int position;

  factory SetlistChord.fromJson(Map<String, dynamic> json) => SetlistChord(
    uuid: jsonText(json, 'uuid'),
    chordName: jsonText(json, 'chordName'),
    artist: jsonText(json, 'artist', fallback: 'Nao informado'),
    addBy: jsonText(json, 'addBy'),
    position: json['position'] as int? ?? 0,
  );
}

class SetlistCollaborator {
  const SetlistCollaborator({
    required this.inviteUuid,
    required this.uuid,
    required this.userName,
    required this.status,
  });

  final String inviteUuid;
  final String uuid;
  final String userName;
  final String status;

  factory SetlistCollaborator.fromJson(Map<String, dynamic> json) =>
      SetlistCollaborator(
        inviteUuid: jsonText(json, 'inviteUuid'),
        uuid: jsonText(json, 'uuid'),
        userName: jsonText(json, 'userName'),
        status: jsonText(json, 'status', fallback: 'PENDING'),
      );
}

class SetlistInvite {
  const SetlistInvite({
    required this.inviteUuid,
    required this.status,
    required this.setlistUuid,
    required this.setlistName,
    required this.ownerUserName,
  });

  final String inviteUuid;
  final String status;
  final String setlistUuid;
  final String setlistName;
  final String ownerUserName;

  factory SetlistInvite.fromJson(Map<String, dynamic> json) => SetlistInvite(
    inviteUuid: jsonText(json, 'inviteUuid'),
    status: jsonText(json, 'status', fallback: 'PENDING'),
    setlistUuid: jsonText(json, 'setlistUuid'),
    setlistName: jsonText(json, 'setlistName'),
    ownerUserName: jsonText(json, 'ownerUserName'),
  );
}

class UserSearchResult {
  const UserSearchResult({
    required this.uuid,
    required this.userName,
    this.profileImageUrl,
  });

  final String uuid;
  final String userName;
  final String? profileImageUrl;

  factory UserSearchResult.fromJson(Map<String, dynamic> json) =>
      UserSearchResult(
        uuid: jsonText(json, 'uuid'),
        userName: jsonText(json, 'userName'),
        profileImageUrl: jsonNullableText(json, 'profileImageUrl'),
      );
}

String jsonText(Map<String, dynamic> json, String key, {String fallback = ''}) {
  final value = json[key];
  if (value == null) return fallback;
  return value.toString();
}

String? jsonNullableText(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

List<String> jsonStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) return const [];
  return value
      .where((item) => item != null)
      .map((item) => item.toString())
      .toList();
}

bool jsonBool(Map<String, dynamic> json, String key, {bool fallback = false}) {
  final value = json[key];
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  return fallback;
}
