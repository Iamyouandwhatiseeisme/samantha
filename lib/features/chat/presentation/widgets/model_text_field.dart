import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:samantha/features/chat/presentation/state/chat_cubit.dart';
import 'package:samantha/features/chat/presentation/state/chat_state.dart';

class _ModelDropdownState {
  final List<ModelProvider> availableModels;
  final String? selectedModel;
  const _ModelDropdownState({required this.availableModels, this.selectedModel});
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
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  String? _lastSelectedQualifier;
  bool _dismissedBySelection = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _removeOverlay();
      _restoreSelectedText();
    }
  }

  void _restoreSelectedText() {
    _dismissedBySelection = false;
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
  }

  List<_FlatModel> _getFilteredModels(List<_FlatModel> allModels) {
    final query = _controller.text.toLowerCase();
    if (query.isEmpty) return allModels;
    return allModels
        .where(
          (m) =>
              m.displayName.toLowerCase().contains(query) ||
              m.providerName.toLowerCase().contains(query),
        )
        .toList();
  }

  void _showOverlay(List<_FlatModel> models) {
    _removeOverlay();
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: models.length,
                itemBuilder: (ctx, index) {
                  final model = models[index];
                  return ListTile(
                    dense: true,
                    title: Text(model.displayName, style: const TextStyle(fontSize: 13)),
                    subtitle: Text(model.providerName, style: const TextStyle(fontSize: 11)),
                    onTap: () {
                      _dismissedBySelection = true;
                      _lastSelectedQualifier = model.qualifiedId;
                      _controller.text = '${model.displayName} (${model.providerName})';
                      context.read<ChatCubit>().setModel(model.qualifiedId);
                      _focusNode.unfocus();
                      _removeOverlay();
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_overlayEntry!);
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
          return const SizedBox(height: 36);
        }

        final allModels = <_FlatModel>[];
        for (final provider in dropdownState.availableModels) {
          for (final model in provider.models) {
            allModels.add(_FlatModel(model.qualifiedId, model.displayName, provider.name));
          }
        }

        final selected = dropdownState.selectedModel;
        if (!_dismissedBySelection && (selected != null || _lastSelectedQualifier != null)) {
          final target = selected ?? _lastSelectedQualifier;
          if (target != null && _controller.text.isEmpty) {
            final match = allModels.where((m) => m.qualifiedId == target);
            if (match.isNotEmpty) {
              final m = match.first;
              _controller.text = '${m.displayName} (${m.providerName})';
              _lastSelectedQualifier = target;
            }
          } else if (target == null) {
            _controller.clear();
          }
        }

        final filtered = _controller.text.isEmpty
            ? allModels
            : allModels
                .where(
                  (m) =>
                      m.displayName.toLowerCase().contains(_controller.text.toLowerCase()) ||
                      m.providerName.toLowerCase().contains(_controller.text.toLowerCase()),
                )
                .toList();

        return CompositedTransformTarget(
          link: _layerLink,
          child: Container(
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    textAlignVertical: TextAlignVertical.center,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: 'Search models...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    ),
                    onTap: () => _showOverlay(filtered),
                    onChanged: (_) {
                      _dismissedBySelection = false;
                      _showOverlay(_getFilteredModels(allModels));
                    },
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                ),
                GestureDetector(
                  onTap: () {
                    _focusNode.requestFocus();
                    _showOverlay(_getFilteredModels(allModels));
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.arrow_drop_down,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
