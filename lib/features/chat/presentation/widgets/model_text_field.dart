import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:samantha/features/chat/presentation/state/chat_cubit.dart';
import 'package:samantha/features/chat/presentation/state/chat_state.dart';

class _ModelDropdownState {
  final List<ModelProvider> availableModels;
  final String? selectedModel;
  const _ModelDropdownState({
    required this.availableModels,
    this.selectedModel,
  });
}

class _FlatModel {
  final String qualifiedId;
  final String displayName;
  final String providerName;
  const _FlatModel(this.qualifiedId, this.displayName, this.providerName);
}

class ModelTextField extends StatefulWidget {
  const ModelTextField({super.key});

  @override
  State<ModelTextField> createState() => _ModelTextFieldState();
}

class _ModelTextFieldState extends State<ModelTextField> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _closeDropdown();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<_FlatModel> _flatten(List<ModelProvider> providers) {
    final flat = <_FlatModel>[];
    for (final provider in providers) {
      for (final model in provider.models) {
        flat.add(_FlatModel(
          model.qualifiedId,
          model.displayName,
          provider.name,
        ));
      }
    }
    return flat;
  }

  String _labelFor(String? selectedId, List<_FlatModel> all) {
    if (selectedId == null) return 'Select model';
    final match = all.where((m) => m.qualifiedId == selectedId);
    if (match.isEmpty) return selectedId;
    final m = match.first;
    return m.displayName;
  }

  void _openDropdown(List<_FlatModel> allModels, String? selectedId) {
    _closeDropdown();
    final renderBox = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final overlay = Overlay.of(context);
    _searchController.clear();

    _overlayEntry = OverlayEntry(
      builder: (ctx) => _ModelDropdownMenu(
        offset: offset,
        width: size.width,
        allModels: allModels,
        selectedId: selectedId,
        searchController: _searchController,
        searchFocusNode: _searchFocusNode,
        onQueryChanged: (q) {
          _overlayEntry?.markNeedsBuild();
        },
        onSelected: (model) {
          context.read<ChatCubit>().setModel(model.qualifiedId);
          _closeDropdown();
        },
        onDismiss: _closeDropdown,
      ),
    );
    overlay.insert(_overlayEntry!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ChatCubit, ChatState, _ModelDropdownState>(
      selector: (state) => _ModelDropdownState(
        availableModels: state.availableModels,
        selectedModel: state.selectedModel,
      ),
      builder: (context, dropdownState) {
        if (dropdownState.availableModels.isEmpty) {
          return const SizedBox(height: 32);
        }

        final allModels = _flatten(dropdownState.availableModels);
        final selectedId = dropdownState.selectedModel;
        final label = _labelFor(selectedId, allModels);

        return Container(
          key: _buttonKey,
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _openDropdown(allModels, selectedId),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          color: selectedId != null
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ModelDropdownMenu extends StatefulWidget {
  final Offset offset;
  final double width;
  final List<_FlatModel> allModels;
  final String? selectedId;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<_FlatModel> onSelected;
  final VoidCallback onDismiss;

  const _ModelDropdownMenu({
    required this.offset,
    required this.width,
    required this.allModels,
    required this.selectedId,
    required this.searchController,
    required this.searchFocusNode,
    required this.onQueryChanged,
    required this.onSelected,
    required this.onDismiss,
  });

  @override
  State<_ModelDropdownMenu> createState() => _ModelDropdownMenuState();
}

class _ModelDropdownMenuState extends State<_ModelDropdownMenu> {
  late String _query;

  @override
  void initState() {
    super.initState();
    _query = '';
    widget.searchController.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final q = widget.searchController.text;
    if (q != _query) {
      _query = q;
      widget.onQueryChanged(q);
    }
  }

  List<_FlatModel> get _filtered {
    if (_query.isEmpty) return List.unmodifiable(widget.allModels);
    final q = _query.toLowerCase();
    return widget.allModels
        .where((m) =>
            m.displayName.toLowerCase().contains(q) ||
            m.providerName.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final menuTop = widget.offset.dy + 36 + 4;
    final menuMaxHeight = (screenSize.height - menuTop - 16).clamp(120.0, 320.0);
    final filtered = _filtered;
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: widget.onDismiss,
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: widget.offset.dx,
          top: menuTop,
          width: widget.width,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: colorScheme.surface,
            child: Container(
              constraints: BoxConstraints(maxHeight: menuMaxHeight),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outlineVariant,
                  width: 0.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                    child: TextField(
                      controller: widget.searchController,
                      focusNode: widget.searchFocusNode,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search models...',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        prefixIcon: Icon(Icons.search, size: 16, color: colorScheme.onSurfaceVariant),
                        prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: colorScheme.outline),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      ),
                      onChanged: widget.onQueryChanged,
                    ),
                  ),
                  Flexible(
                    child: filtered.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'No models found',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.only(bottom: 4),
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              thickness: 0.5,
                              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                            ),
                            itemBuilder: (context, index) {
                              final model = filtered[index];
                              final isSelected = model.qualifiedId == widget.selectedId;
                              return InkWell(
                                onTap: () => widget.onSelected(model),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  color: isSelected
                                      ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                                      : null,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              model.displayName,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                                color: colorScheme.onSurface,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              model.providerName,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: colorScheme.onSurfaceVariant,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check,
                                          size: 16,
                                          color: colorScheme.primary,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}