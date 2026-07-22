import 'package:flutter/material.dart';

class SearchableList extends StatefulWidget {
  final Widget child;
  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onSearchDismissed;

  const SearchableList({
    required this.child,
    required this.searchHint,
    required this.onSearchChanged,
    this.onSearchDismissed,
  });

  @override
  State<SearchableList> createState() => _SearchableListState();
}

class _SearchableListState extends State<SearchableList> with SingleTickerProviderStateMixin {
  bool _searchVisible = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _showSearch() {
    setState(() {
      _searchVisible = true;
    });
    _animationController.forward();
    _searchFocus.requestFocus();
  }

  void _hideSearch() {
    _animationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _searchVisible = false;
        });
        _searchController.clear();
        widget.onSearchChanged('');
        widget.onSearchDismissed?.call();
      }
    });
  }

  void _onSearchChanged(String value) {
    widget.onSearchChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is OverscrollNotification &&
            notification.overscroll < -30 &&
            notification.metrics.pixels <= 0 &&
            !_searchVisible) {
          _showSearch();
          return true;
        }
        return false;
      },
      child: Column(
        children: [
          if (_searchVisible)
            SizeTransition(
              sizeFactor: _animation,
              child: _SearchBar(
                controller: _searchController,
                focusNode: _searchFocus,
                hint: widget.searchHint,
                onChanged: _onSearchChanged,
                onClear: _hideSearch,
              ),
            ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surface,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: onClear,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.colorScheme.primary),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          isDense: true,
        ),
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
      ),
    );
  }
}
