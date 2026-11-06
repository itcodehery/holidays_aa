import 'dart:typed_data';

/// Whether supporting documents are needed for a given leave type and duration.
enum ProofRequirement { none, optional, required }

/// In-memory file selected by the user before upload.
/// Holds bytes rather than file paths for full Flutter web compatibility.
class PickedAttachment {
  final String name;
  final Uint8List bytes;
  final String mimeType;

  int get sizeBytes => bytes.lengthInBytes;

  const PickedAttachment(this.name, this.bytes, this.mimeType);
}

/// Persisted metadata for an uploaded leave attachment.
class Attachment {
  final String id;
  final String requestId;
  final String fileName;
  final String storagePath;
  final String mimeType;
  final int sizeBytes;
  final DateTime uploadedAt;

  const Attachment({
    required this.id,
    required this.requestId,
    required this.fileName,
    required this.storagePath,
    required this.mimeType,
    required this.sizeBytes,
    required this.uploadedAt,
  });

  bool get isImage {
    final lower = mimeType.toLowerCase();
    final ext = fileName.split('.').last.toLowerCase();
    return lower.startsWith('image/') ||
        ext == 'jpg' ||
        ext == 'jpeg' ||
        ext == 'png';
  }

  bool get isPdf {
    final lower = mimeType.toLowerCase();
    final ext = fileName.split('.').last.toLowerCase();
    return lower == 'application/pdf' || ext == 'pdf';
  }

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: json['id'] as String,
      requestId: json['request_id'] as String,
      fileName: json['file_name'] as String,
      storagePath: json['storage_path'] as String,
      mimeType: json['mime_type'] as String,
      sizeBytes: json['size_bytes'] as int,
      uploadedAt: json['uploaded_at'] != null
          ? DateTime.parse(json['uploaded_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'request_id': requestId,
        'file_name': fileName,
        'storage_path': storagePath,
        'mime_type': mimeType,
        'size_bytes': sizeBytes,
        'uploaded_at': uploadedAt.toIso8601String(),
      };
}
