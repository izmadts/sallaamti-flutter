import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/state/auth_controller.dart';

// Same fixed set as the backend's Reaction::TYPES — an "Ameen"-style
// reaction shared by duas and posts alike.
const wallReactionTypes = {
  'ameen': ('🤲', 'Ameen'),
  'jazakallah': ('🌟', 'JazakAllah'),
  'mashaallah': ('✨', 'MashaAllah'),
};

class WallAuthor {
  final String name;
  final String? avatar;
  WallAuthor({required this.name, this.avatar});

  factory WallAuthor.fromJson(Map<String, dynamic> json) => WallAuthor(
        name: json['name'] as String,
        avatar: json['avatar'] as String?,
      );
}

class WallMediaItem {
  final String type; // 'image' | 'video'
  final String url;
  WallMediaItem({required this.type, required this.url});

  bool get isVideo => type == 'video';

  factory WallMediaItem.fromJson(Map<String, dynamic> json) => WallMediaItem(
        type: json['type'] as String? ?? 'image',
        url: json['url'] as String? ?? '',
      );
}

class PollOption {
  final int index;
  final String label;
  final int votes;
  final int percentage;
  PollOption({required this.index, required this.label, required this.votes, required this.percentage});

  factory PollOption.fromJson(Map<String, dynamic> json) => PollOption(
        index: _asInt(json['index']) ?? 0,
        label: json['label'] as String? ?? '',
        votes: _asInt(json['votes']) ?? 0,
        percentage: _asInt(json['percentage']) ?? 0,
      );
}

class WallItem {
  final String type; // 'dua' | 'post'
  final int id;
  final WallAuthor? author;
  final bool isAnonymous;
  final String? title;
  final String body;
  final String? photoUrl;
  final String? videoUrl;
  final List<WallMediaItem> media;
  final List<String> tags;
  final DateTime? eventAt;
  final bool isPinned;
  final Map<String, int> reactionCounts;
  final String? myReaction;
  final int commentsCount;
  final bool isSaved;
  final DateTime createdAt;
  final String? shareUrl;
  // Only non-null for a 'post' created as a poll — a 'dua' never is.
  final List<PollOption>? pollResults;
  final int? myPollVote;

  bool get isPoll => pollResults != null;

  WallItem({
    required this.type,
    required this.id,
    this.author,
    required this.isAnonymous,
    this.title,
    required this.body,
    this.photoUrl,
    this.videoUrl,
    this.media = const [],
    required this.tags,
    this.eventAt,
    required this.isPinned,
    required this.reactionCounts,
    this.myReaction,
    required this.commentsCount,
    required this.isSaved,
    required this.createdAt,
    this.shareUrl,
    this.pollResults,
    this.myPollVote,
  });

  WallItem copyWith({
    Map<String, int>? reactionCounts,
    String? myReaction,
    bool clearMyReaction = false,
    bool? isSaved,
    List<PollOption>? pollResults,
    int? myPollVote,
  }) =>
      WallItem(
        type: type,
        id: id,
        author: author,
        isAnonymous: isAnonymous,
        title: title,
        body: body,
        photoUrl: photoUrl,
        videoUrl: videoUrl,
        media: media,
        tags: tags,
        eventAt: eventAt,
        isPinned: isPinned,
        reactionCounts: reactionCounts ?? this.reactionCounts,
        myReaction: clearMyReaction ? null : (myReaction ?? this.myReaction),
        commentsCount: commentsCount,
        isSaved: isSaved ?? this.isSaved,
        createdAt: createdAt,
        shareUrl: shareUrl,
        pollResults: pollResults ?? this.pollResults,
        myPollVote: myPollVote ?? this.myPollVote,
      );

  factory WallItem.fromJson(Map<String, dynamic> json) => WallItem(
        type: json['type'] as String,
        id: _asInt(json['id']) ?? 0,
        author: json['author'] != null ? WallAuthor.fromJson(Map<String, dynamic>.from(json['author'] as Map)) : null,
        isAnonymous: json['is_anonymous'] as bool? ?? false,
        title: json['title'] as String?,
        body: json['body'] as String? ?? '',
        photoUrl: json['photo_url'] as String?,
        videoUrl: json['video_url'] as String?,
        media: _asList(json['media']).map((e) => WallMediaItem.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        tags: _asList(json['tags']).map((e) => e.toString()).toList(),
        eventAt: json['event_at'] != null ? DateTime.tryParse(json['event_at'].toString()) : null,
        isPinned: json['is_pinned'] as bool? ?? false,
        reactionCounts: Map<String, int>.from((json['reaction_counts'] as Map?)?.map((k, v) => MapEntry(k.toString(), _asInt(v) ?? 0)) ?? {}),
        myReaction: json['my_reaction'] as String?,
        commentsCount: _asInt(json['comments_count']) ?? 0,
        isSaved: json['is_saved'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
        shareUrl: json['share_url'] as String?,
        pollResults: json['poll_results'] != null
            ? _asList(json['poll_results']).map((e) => PollOption.fromJson(Map<String, dynamic>.from(e as Map))).toList()
            : null,
        myPollVote: _asInt(json['my_poll_vote']),
      );
}

class WallComment {
  final int id;
  final WallAuthor? author;
  final String body;
  final int? parentId;
  final DateTime createdAt;
  final List<WallComment> replies;

  WallComment({required this.id, this.author, required this.body, this.parentId, required this.createdAt, required this.replies});

  factory WallComment.fromJson(Map<String, dynamic> json) => WallComment(
        id: _asInt(json['id']) ?? 0,
        author: json['author'] != null ? WallAuthor.fromJson(Map<String, dynamic>.from(json['author'] as Map)) : null,
        body: json['body'] as String,
        parentId: _asInt(json['parent_id']),
        createdAt: DateTime.parse(json['created_at'] as String),
        replies: _asList(json['replies']).map((e) => WallComment.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      );
}

class WallFeedPage {
  final List<WallItem> items;
  final bool hasMore;
  final List<String> tags;
  WallFeedPage({required this.items, required this.hasMore, required this.tags});
}

List<dynamic> _asList(dynamic value) {
  if (value is List) return value;
  if (value is Map) return value.values.toList();
  return [];
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

class WallRepository {
  final ApiClient _client;
  WallRepository(this._client);

  Future<WallFeedPage> feed({String? tag, int page = 1}) async {
    final data = await _client.get('/wall', query: {
      if (tag != null && tag.isNotEmpty) 'tag': tag,
      'page': page,
    });
    return WallFeedPage(
      items: (data['items'] as List).map((e) => WallItem.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      hasMore: data['has_more'] as bool? ?? false,
      tags: _asList(data['tags']).map((e) => e.toString()).toList(),
    );
  }

  Future<WallFeedPage> saved({int page = 1}) async {
    final data = await _client.get('/wall/saved', query: {'page': page});
    return WallFeedPage(
      items: (data['items'] as List).map((e) => WallItem.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      hasMore: data['has_more'] as bool? ?? false,
      tags: const [],
    );
  }

  Future<void> submitDua({required String body, bool isAnonymous = false, List<File> images = const []}) =>
      _client.postMultipart('/wall/dua', fields: {
        'body': body,
        'is_anonymous': isAnonymous,
      }, files: {
        if (images.isNotEmpty) 'images[]': images,
      });

  Future<WallItem> react(String type, int id, String reactionType) async {
    final data = await _client.post('/wall/$type/$id/react', data: {'type': reactionType});
    return WallItem.fromJson(data);
  }

  // Returns just the (index, pollResults, myPollVote) triple, not a whole
  // WallItem — the caller already has everything else and only needs to
  // patch these two fields in place, same reasoning as react()/toggleSave()
  // returning the minimum needed.
  Future<(List<PollOption>, int)> vote(String type, int id, int optionIndex) async {
    final data = await _client.post('/wall/$type/$id/vote', data: {'option_index': optionIndex});
    return (
      (data['poll_results'] as List).map((e) => PollOption.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      data['my_poll_vote'] as int,
    );
  }

  Future<bool> toggleSave(String type, int id) async {
    final data = await _client.post('/wall/$type/$id/save');
    return data['is_saved'] as bool;
  }

  Future<List<WallComment>> comments(String type, int id) async {
    final data = await _client.get('/wall/$type/$id/comments');
    return (data['comments'] as List).map((e) => WallComment.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<WallComment> postComment(String type, int id, {required String body, int? parentId}) async {
    final data = await _client.post('/wall/$type/$id/comments', data: {'body': body, 'parent_id': parentId});
    return WallComment.fromJson(Map<String, dynamic>.from(data['comment'] as Map));
  }
}

final wallRepositoryProvider = Provider((ref) => WallRepository(ref.watch(apiClientProvider)));
