import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();
  final _uuid = const Uuid();

  // ── Pick image from gallery or camera ─────────────────────────────────────
  Future<File?> pickImage({
    ImageSource source = ImageSource.gallery,
    int imageQuality = 80,
  }) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: imageQuality,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  // ── Upload exhibitor logo ─────────────────────────────────────────────────
  Future<String?> uploadExhibitorLogo({
    required File imageFile,
    required String exhibitorId,
    void Function(double progress)? onProgress,
  }) async {
    return _uploadFile(
      file: imageFile,
      path: 'exhibitors/$exhibitorId/logo_${_uuid.v4()}.jpg',
      onProgress: onProgress,
    );
  }

  // ── Upload puzzle image ───────────────────────────────────────────────────
  Future<String?> uploadPuzzleImage({
    required File imageFile,
    required String exhibitorId,
    void Function(double progress)? onProgress,
  }) async {
    return _uploadFile(
      file: imageFile,
      path: 'puzzles/$exhibitorId/puzzle_${_uuid.v4()}.jpg',
      onProgress: onProgress,
    );
  }

  // ── Upload any image with progress callback ───────────────────────────────
  Future<String?> _uploadFile({
    required File file,
    required String path,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final ref = _storage.ref().child(path);
      final task = ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      if (onProgress != null) {
        task.snapshotEvents.listen((snap) {
          final progress =
              snap.bytesTransferred / snap.totalBytes;
          onProgress(progress);
        });
      }

      await task;
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } on FirebaseException catch (e) {
      // ignore: avoid_print
      print('StorageService upload error: ${e.message}');
      return null;
    }
  }

  // ── Delete a file by its download URL ─────────────────────────────────────
  Future<void> deleteByUrl(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } on FirebaseException catch (e) {
      // ignore: avoid_print
      print('StorageService delete error: ${e.message}');
    }
  }

  // ── Pick & upload exhibitor logo (combined helper) ─────────────────────────
  Future<String?> pickAndUploadLogo({
    required String exhibitorId,
    ImageSource source = ImageSource.gallery,
    void Function(double progress)? onProgress,
  }) async {
    final file = await pickImage(source: source);
    if (file == null) return null;
    return uploadExhibitorLogo(
      imageFile: file,
      exhibitorId: exhibitorId,
      onProgress: onProgress,
    );
  }
}
