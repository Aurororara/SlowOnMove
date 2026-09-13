import 'package:flutter/material.dart';

import '../../community_store.dart';

class CommentsSheet extends StatefulWidget {
  final CommunityStore store;
  final int postId;

  const CommentsSheet({
    super.key,
    required this.store,
    required this.postId,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _controller = TextEditingController();

  List<Map<String, dynamic>> _comments = [];

  bool _isLoading = true;
  bool _isSending = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  Future<void> _loadComments() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final comments = await widget.store.loadComments(
      widget.postId,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _comments = comments;
      _isLoading = false;

      if (widget.store.errorMessage != null && comments.isEmpty) {
        _errorMessage = widget.store.errorMessage;
      }
    });
  }

  Future<void> _sendComment() async {
    final content = _controller.text.trim();

    if (content.isEmpty || _isSending) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    final success = await widget.store.addCommentByPostId(
      widget.postId,
      content,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      setState(() {
        _isSending = false;
        _errorMessage = widget.store.errorMessage ?? '留言失敗';
      });

      return;
    }

    _controller.clear();

    final comments = await widget.store.loadComments(
      widget.postId,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _comments = comments;
      _isSending = false;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        16 + bottomInset,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(),
            const SizedBox(height: 16),
            _buildHeader(),
            const SizedBox(height: 12),
            Flexible(
              child: _buildCommentsContent(),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              _buildErrorMessage(),
            ],
            const SizedBox(height: 12),
            _buildCommentInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 42,
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFFD1D5DB),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  Widget _buildHeader() {
    return const Row(
      children: [
        Text(
          '留言',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildCommentsContent() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_comments.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: 36,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 36,
                color: Color(0xFFCBD5E1),
              ),
              SizedBox(height: 12),
              Text(
                '目前還沒有留言',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '成為第一個留言的人吧',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadComments,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: _comments.length,
        separatorBuilder: (_, __) => const Divider(
          height: 20,
          color: Color(0xFFF1F5F9),
        ),
        itemBuilder: (context, index) {
          final comment = _comments[index];

          return _CommentItem(
            comment: comment,
          );
        },
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            size: 16,
            color: Colors.redAccent,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: '新增留言...',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFFE2E8F0),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFFE2E8F0),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF94A3B8),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 46,
          height: 46,
          child: IconButton.filled(
            onPressed: _isSending ? null : _sendComment,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              disabledBackgroundColor: const Color(0xFFCBD5E1),
            ),
            icon: _isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.send_rounded,
                    size: 20,
                  ),
          ),
        ),
      ],
    );
  }
}

class _CommentItem extends StatelessWidget {
  final Map<String, dynamic> comment;

  const _CommentItem({
    required this.comment,
  });

  @override
  Widget build(BuildContext context) {
    final name = (comment['member_name'] ?? '使用者').toString();

    final initial =
        (comment['member_initial'] ?? (name.isNotEmpty ? name[0] : 'U'))
            .toString();

    final content = (comment['content'] ?? '').toString();

    final createdAt = _formatCreatedAt(
      comment['created_at'],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFF0F172A),
          child: Text(
            initial.isNotEmpty ? initial[0].toUpperCase() : 'U',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (createdAt.isNotEmpty)
                    Text(
                      createdAt,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatCreatedAt(dynamic value) {
    if (value == null) {
      return '';
    }

    final date = DateTime.tryParse(
      value.toString(),
    );

    if (date == null) {
      return '';
    }

    final local = date.toLocal();
    final now = DateTime.now();

    final difference = now.difference(local);

    if (difference.inMinutes < 1) {
      return '剛剛';
    }

    if (difference.inHours < 1) {
      return '${difference.inMinutes} 分鐘前';
    }

    if (difference.inDays < 1) {
      return '${difference.inHours} 小時前';
    }

    if (difference.inDays == 1) {
      return '昨天';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays} 天前';
    }

    return '${local.month}/${local.day}';
  }
}
