import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/user_messages.dart';

final chordsRepositoryProvider = Provider<ChordsRepository>((ref) {
  return ChordsRepository(ref.watch(apiClientProvider));
});

final myChordsProvider = FutureProvider.autoDispose<List<ChordSummary>>((ref) {
  return ref.watch(chordsRepositoryProvider).mine();
});

const maxChordUploadSizeBytes = 30 * 1024 * 1024;

final chordSearchProvider = FutureProvider.autoDispose
    .family<List<ChordSummary>, String>((ref, query) {
      return ref.watch(chordsRepositoryProvider).search(query);
    });

class ChordsRepository {
  ChordsRepository(this._api);

  final ApiClient _api;

  Future<List<ChordSummary>> mine() async {
    final response = await _api.get<List<dynamic>>('/chord/me');
    return (response.data ?? const [])
        .map((item) => ChordSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ChordSummary>> search(String query) async {
    if (query.trim().isEmpty) return const [];
    try {
      final response = await _api.get<List<dynamic>>(
        '/chord/search',
        queryParameters: {'chordName': query.trim()},
      );
      return (response.data ?? const [])
          .map((item) => ChordSummary.fromJson(item as Map<String, dynamic>))
          .toList();
    } on ApiException catch (error) {
      if (error.statusCode == 400 || error.statusCode == 404) {
        return const [];
      }
      rethrow;
    }
  }

  Future<ChordDetail> getById(String uuid) async {
    final response = await _api.get<Map<String, dynamic>>('/chord/$uuid');
    return ChordDetail.fromJson(response.data!);
  }

  Future<ChordPreview> preview(PlatformFile file) async {
    if (!isSupportedChordImportFile(file)) {
      throw const ApiException(chordDocumentsOnlyMessage, statusCode: 400);
    }

    final contentType = _contentTypeFor(file.name);
    final multipart = file.bytes != null
        ? MultipartFile.fromBytes(
            file.bytes!,
            filename: file.name,
            contentType: contentType,
          )
        : await MultipartFile.fromFile(
            file.path!,
            filename: file.name,
            contentType: contentType,
          );
    final response = await _api.multipart<Map<String, dynamic>>(
      '/chord/preview',
      FormData.fromMap({'file': multipart}),
    );
    return ChordPreview.fromJson(response.data!);
  }

  Future<String> confirm({
    required String uuid,
    required String chordName,
    required String artist,
    required String chordPro,
  }) async {
    final response = await _api.put<Map<String, dynamic>>(
      '/chord/confirm/$uuid',
      data: {'chordName': chordName, 'artist': artist, 'chordPro': chordPro},
    );
    return response.data!['uuid'] as String;
  }

  Future<ChordDetail> update({
    required String uuid,
    required String chordName,
    required String artist,
    required String chordPro,
  }) async {
    final response = await _api.put<Map<String, dynamic>>(
      '/chord/$uuid',
      data: {'chordName': chordName, 'artist': artist, 'chordPro': chordPro},
    );
    return ChordDetail.fromJson(response.data!);
  }

  Future<void> delete(String uuid) => _api.delete<void>('/chord/$uuid');
}

@visibleForTesting
DioMediaType contentTypeForChordUpload(String filename) {
  final extension = filename.split('.').last.toLowerCase();
  return switch (extension) {
    'pdf' => DioMediaType.parse('application/pdf'),
    'txt' => DioMediaType.parse('text/plain'),
    _ => DioMediaType.parse('application/octet-stream'),
  };
}

DioMediaType _contentTypeFor(String filename) =>
    contentTypeForChordUpload(filename);

bool isChordUploadTooLarge(PlatformFile file) {
  return file.size > maxChordUploadSizeBytes;
}

bool isSupportedChordImportFile(PlatformFile file) {
  final extension = file.name.split('.').last.toLowerCase();
  return extension == 'pdf' || extension == 'txt';
}
