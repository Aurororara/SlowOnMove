import 'dart:async';
import 'package:flutter/material.dart';

class FriendSearchField extends StatefulWidget {
  final ValueChanged<String> onChanged;

  const FriendSearchField({
    super.key,
    required this.onChanged,
  });

  @override
  State<FriendSearchField> createState() => _FriendSearchFieldState();
}

class _FriendSearchFieldState extends State<FriendSearchField> {
  final TextEditingController _controller = TextEditingController();

  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    setState(() {});

    _debounce?.cancel();

    _debounce = Timer(
      const Duration(milliseconds: 400),
      () {
        widget.onChanged(value.trim());
      },
    );
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search,
            color: Color(0xFFA0AEC0),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: _handleChanged,
              decoration: const InputDecoration(
                hintText: '搜尋姓名、帳號或 Email',
                hintStyle: TextStyle(
                  color: Color(0xFF718096),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            InkWell(
              onTap: _clear,
              borderRadius: BorderRadius.circular(999),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  color: Color(0xFFA0AEC0),
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
