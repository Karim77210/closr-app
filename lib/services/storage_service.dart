import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadProfileImage(String uid, XFile imageFile) async {
    final ext = imageFile.name.split('.').last.toLowerCase();
    final contentType = _contentType(ext.isEmpty ? 'jpg' : ext);
    final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.${ext.isEmpty ? 'jpg' : ext}';
    final ref = _storage.ref('profile_images/$uid/$fileName');
    final bytes = await imageFile.readAsBytes();
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return await ref.getDownloadURL();
  }

  Future<String> uploadChatMedia(String conversationId, XFile file) async {
    final ext = file.name.split('.').last.toLowerCase();
    final contentType = _contentType(ext);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final ref = _storage.ref('conversations/$conversationId/$fileName');
    final bytes = await file.readAsBytes();

    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return await ref.getDownloadURL();
  }

  String _contentType(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      default:
        return 'application/octet-stream';
    }
  }
}
