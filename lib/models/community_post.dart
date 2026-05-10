class CommunityPost {
  final String initial;
  final String name;
  final String timeAgo;
  final String content;
  final List<String> tags;
  final int likes;
  final List<String> commentThreads;
  final bool isLiked;
  final bool isSaved;

  const CommunityPost({
    required this.initial,
    required this.name,
    required this.timeAgo,
    required this.content,
    required this.tags,
    required this.likes,
    required this.commentThreads,
    this.isLiked = false,
    this.isSaved = false,
  });

  int get commentCount => commentThreads.length;

  CommunityPost copyWith({
    String? initial,
    String? name,
    String? timeAgo,
    String? content,
    List<String>? tags,
    int? likes,
    List<String>? commentThreads,
    bool? isLiked,
    bool? isSaved,
  }) {
    return CommunityPost(
      initial: initial ?? this.initial,
      name: name ?? this.name,
      timeAgo: timeAgo ?? this.timeAgo,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      likes: likes ?? this.likes,
      commentThreads: commentThreads ?? this.commentThreads,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
    );
  }
}
