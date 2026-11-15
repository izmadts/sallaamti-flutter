int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

// Mirrors Api\V1\LibraryController::cardPayload() — pdf_url/share_url/
// review_note are only present on the detailed (show()) response, never on
// the list, so they stay nullable here rather than two separate classes.
class LibraryItem {
  final int id;
  final String? code;
  final String title;
  final String slug;
  final String category;
  final String? description;
  final String? coverUrl;
  final int? pages;
  final int? fileSize;
  final String language;
  final int version;
  final DateTime? publishedAt;
  final bool isNew;
  final String? reviewNote;
  final String? pdfUrl;
  final String? shareUrl;

  LibraryItem({
    required this.id,
    this.code,
    required this.title,
    required this.slug,
    required this.category,
    this.description,
    this.coverUrl,
    this.pages,
    this.fileSize,
    required this.language,
    required this.version,
    this.publishedAt,
    this.isNew = false,
    this.reviewNote,
    this.pdfUrl,
    this.shareUrl,
  });

  // "1.2 MB" / "480 KB" — same thresholds as LibraryItem::fileSizeHuman()
  // on the backend, so the number shown here always matches the website.
  String? get fileSizeHuman {
    if (fileSize == null || fileSize == 0) return null;
    final mb = fileSize! / 1048576;
    return mb >= 0.1 ? '${mb.toStringAsFixed(1)} MB' : '${(fileSize! / 1024).round()} KB';
  }

  factory LibraryItem.fromJson(Map<String, dynamic> json) => LibraryItem(
        id: _asInt(json['id']) ?? 0,
        code: json['code'] as String?,
        title: json['title'] as String? ?? '',
        slug: json['slug'] as String? ?? '',
        category: json['category'] as String? ?? '',
        description: json['description'] as String?,
        coverUrl: json['cover_url'] as String?,
        pages: _asInt(json['pages']),
        fileSize: _asInt(json['file_size']),
        language: json['language'] as String? ?? 'ur',
        version: _asInt(json['version']) ?? 1,
        publishedAt: json['published_at'] != null ? DateTime.tryParse(json['published_at'] as String) : null,
        isNew: json['is_new'] as bool? ?? false,
        reviewNote: json['review_note'] as String?,
        pdfUrl: json['pdf_url'] as String?,
        shareUrl: json['share_url'] as String?,
      );
}

class LibraryCategory {
  final String key;
  final String labelUr;
  final String labelEn;
  final String icon;
  final int count;

  LibraryCategory({required this.key, required this.labelUr, required this.labelEn, required this.icon, required this.count});

  factory LibraryCategory.fromJson(Map<String, dynamic> json) => LibraryCategory(
        key: json['key'] as String? ?? '',
        labelUr: json['label_ur'] as String? ?? '',
        labelEn: json['label_en'] as String? ?? '',
        icon: json['icon'] as String? ?? '📚',
        count: _asInt(json['count']) ?? 0,
      );
}
