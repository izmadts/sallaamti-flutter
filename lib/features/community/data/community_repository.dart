import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/state/auth_controller.dart';

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

// Every community list endpoint pages the same way, so one holder carries the
// items plus whether there's more to fetch.
class Paged<T> {
  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final bool hasMore;

  Paged({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.hasMore,
  });

  factory Paged.fromJson(
    Map<String, dynamic> json,
    String key,
    T Function(Map<String, dynamic>) parse,
  ) {
    final meta = Map<String, dynamic>.from(json['meta'] as Map? ?? const {});

    return Paged(
      items: (json[key] as List).map((e) => parse(Map<String, dynamic>.from(e as Map))).toList(),
      currentPage: _asInt(meta['current_page']) ?? 1,
      lastPage: _asInt(meta['last_page']) ?? 1,
      total: _asInt(meta['total']) ?? 0,
      hasMore: meta['has_more'] as bool? ?? false,
    );
  }
}

class CommunityAuthor {
  final int id;
  final String name;
  final String? avatar;

  CommunityAuthor({required this.id, required this.name, this.avatar});

  factory CommunityAuthor.fromJson(Map<String, dynamic> json) => CommunityAuthor(
        id: _asInt(json['id']) ?? 0,
        name: json['name'] as String? ?? '',
        avatar: json['avatar'] as String?,
      );
}

class BlogArticle {
  final int id;
  final String title;
  final String? category;
  final String? excerpt;
  final String? content;
  final String? coverImageUrl;
  final DateTime? publishedAt;
  final CommunityAuthor? author;

  BlogArticle({
    required this.id,
    required this.title,
    this.category,
    this.excerpt,
    this.content,
    this.coverImageUrl,
    this.publishedAt,
    this.author,
  });

  factory BlogArticle.fromJson(Map<String, dynamic> json) => BlogArticle(
        id: _asInt(json['id']) ?? 0,
        title: json['title'] as String? ?? '',
        category: json['category'] as String?,
        excerpt: json['excerpt'] as String?,
        content: json['content'] as String?,
        coverImageUrl: json['cover_image_url'] as String?,
        publishedAt: json['published_at'] != null ? DateTime.tryParse(json['published_at'] as String) : null,
        author: json['author'] != null ? CommunityAuthor.fromJson(Map<String, dynamic>.from(json['author'] as Map)) : null,
      );
}

class MemberPost {
  final int id;
  final String title;
  final String? slug;
  final String? excerpt;
  final String? body;
  final String? coverImageUrl;
  final String status;
  final String? rejectionReason;
  final int viewsCount;
  final String? shareUrl;
  final DateTime? publishedAt;
  final DateTime? createdAt;
  final CommunityAuthor? author;

  MemberPost({
    required this.id,
    required this.title,
    this.slug,
    this.excerpt,
    this.body,
    this.coverImageUrl,
    required this.status,
    this.rejectionReason,
    required this.viewsCount,
    this.shareUrl,
    this.publishedAt,
    this.createdAt,
    this.author,
  });

  bool get isPublished => status == 'published';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';

  factory MemberPost.fromJson(Map<String, dynamic> json) => MemberPost(
        id: _asInt(json['id']) ?? 0,
        title: json['title'] as String? ?? '',
        slug: json['slug'] as String?,
        excerpt: json['excerpt'] as String?,
        body: json['body'] as String?,
        coverImageUrl: json['cover_image_url'] as String?,
        status: json['status'] as String? ?? 'pending',
        rejectionReason: json['rejection_reason'] as String?,
        viewsCount: _asInt(json['views_count']) ?? 0,
        shareUrl: json['share_url'] as String?,
        publishedAt: json['published_at'] != null ? DateTime.tryParse(json['published_at'] as String) : null,
        createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
        author: json['author'] != null ? CommunityAuthor.fromJson(Map<String, dynamic>.from(json['author'] as Map)) : null,
      );
}

class MemberTestimonial {
  final int id;
  final String name;
  final String? location;
  final String content;
  final int rating;
  final String? photoUrl;
  final String status;
  final String? rejectionReason;
  final DateTime? createdAt;

  MemberTestimonial({
    required this.id,
    required this.name,
    this.location,
    required this.content,
    required this.rating,
    this.photoUrl,
    required this.status,
    this.rejectionReason,
    this.createdAt,
  });

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';

  factory MemberTestimonial.fromJson(Map<String, dynamic> json) => MemberTestimonial(
        id: _asInt(json['id']) ?? 0,
        name: json['name'] as String? ?? '',
        location: json['location'] as String?,
        content: json['content'] as String? ?? '',
        rating: _asInt(json['rating']) ?? 5,
        photoUrl: json['photo_url'] as String?,
        status: json['status'] as String? ?? 'pending',
        rejectionReason: json['rejection_reason'] as String?,
        createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      );
}

class CommunityRepository {
  final ApiClient _client;
  CommunityRepository(this._client);

  Future<Paged<BlogArticle>> blog({int page = 1}) async {
    final data = await _client.get('/blog', query: {'page': page});
    return Paged.fromJson(data, 'posts', BlogArticle.fromJson);
  }

  Future<BlogArticle> blogArticle(int id) async {
    final data = await _client.get('/blog/$id');
    return BlogArticle.fromJson(Map<String, dynamic>.from(data['post'] as Map));
  }

  Future<Paged<MemberPost>> posts({int page = 1}) async {
    final data = await _client.get('/posts', query: {'page': page});
    return Paged.fromJson(data, 'posts', MemberPost.fromJson);
  }

  Future<Paged<MemberPost>> myPosts({int page = 1}) async {
    final data = await _client.get('/posts/mine', query: {'page': page});
    return Paged.fromJson(data, 'posts', MemberPost.fromJson);
  }

  Future<MemberPost> post(int id) async {
    final data = await _client.get('/posts/$id');
    return MemberPost.fromJson(Map<String, dynamic>.from(data['post'] as Map));
  }

  // Multipart even without a cover image, so one code path covers both — the
  // backend reads the same fields either way.
  Future<(MemberPost, String)> savePost({
    int? id,
    required String title,
    required String body,
    String? excerpt,
    File? coverImage,
  }) async {
    final data = await _client.postMultipart(
      id == null ? '/posts' : '/posts/$id',
      fields: {'title': title, 'body': body, 'excerpt': excerpt},
      files: {if (coverImage != null) 'cover_image': coverImage},
    );

    return (
      MemberPost.fromJson(Map<String, dynamic>.from(data['post'] as Map)),
      data['message'] as String? ?? '',
    );
  }

  Future<void> deletePost(int id) => _client.delete('/posts/$id');

  Future<Paged<MemberTestimonial>> testimonials({int page = 1}) async {
    final data = await _client.get('/testimonials', query: {'page': page});
    return Paged.fromJson(data, 'testimonials', MemberTestimonial.fromJson);
  }

  Future<Paged<MemberTestimonial>> myTestimonials({int page = 1}) async {
    final data = await _client.get('/testimonials/mine', query: {'page': page});
    return Paged.fromJson(data, 'testimonials', MemberTestimonial.fromJson);
  }

  Future<(MemberTestimonial, String)> saveTestimonial({
    int? id,
    required String name,
    String? location,
    required String content,
    required int rating,
    File? photo,
  }) async {
    final data = await _client.postMultipart(
      id == null ? '/testimonials' : '/testimonials/$id',
      fields: {'name': name, 'location': location, 'content': content, 'rating': rating},
      files: {if (photo != null) 'photo': photo},
    );

    return (
      MemberTestimonial.fromJson(Map<String, dynamic>.from(data['testimonial'] as Map)),
      data['message'] as String? ?? '',
    );
  }

  Future<void> deleteTestimonial(int id) => _client.delete('/testimonials/$id');
}

final communityRepositoryProvider = Provider((ref) => CommunityRepository(ref.watch(apiClientProvider)));
