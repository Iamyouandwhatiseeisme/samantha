import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:samantha/app/theme.dart';
import 'package:samantha/features/chat/presentation/state/chat_cubit.dart';
import 'package:samantha/features/chat/presentation/state/chat_state.dart';

class _ModelPickerState {
  final List<ModelProvider> availableModels;
  final String? selectedModel;
  const _ModelPickerState({
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

  @override
  void dispose() {
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
    if (match.isEmpty) return selectedId.split('/').last;
    return match.first.displayName;
  }

  void _openSheet(List<_FlatModel> allModels, String? selectedId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _ModelPickerSheet(
        allModels: allModels,
        selectedId: selectedId,
        onSelected: (model) {
          context.read<ChatCubit>().setModel(model.qualifiedId);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);

    return BlocSelector<ChatCubit, ChatState, _ModelPickerState>(
      selector: (state) => _ModelPickerState(
        availableModels: state.availableModels,
        selectedModel: state.selectedModel,
      ),
      builder: (context, pickerState) {
        if (pickerState.availableModels.isEmpty) {
          return const SizedBox(height: 32);
        }

        final allModels = _flatten(pickerState.availableModels);
        final selectedId = pickerState.selectedModel;
        final label = _labelFor(selectedId, allModels);

        return GestureDetector(
          onTap: () => _openSheet(allModels, selectedId),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.memory,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: colors.mono,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: selectedId != null
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ModelPickerSheet extends StatefulWidget {
  final List<_FlatModel> allModels;
  final String? selectedId;
  final ValueChanged<_FlatModel> onSelected;

  const _ModelPickerSheet({
    required this.allModels,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  State<_ModelPickerSheet> createState() => _ModelPickerSheetState();
}

class _ModelPickerSheetState extends State<_ModelPickerSheet> {
  String _query = '';

  List<_FlatModel> get _filtered {
    if (_query.isEmpty) return widget.allModels;
    final q = _query.toLowerCase();
    return widget.allModels
        .where((m) =>
            m.displayName.toLowerCase().contains(q) ||
            m.providerName.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final filtered = _filtered;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Text(
                  'Select Model',
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: TextEditingController(text: _query),
              autofocus: true,
              style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Search models\u2026',
                prefixIcon: const Icon(Icons.search, size: 18),
                prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No models found',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 16),
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      thickness: 0.5,
                      color: theme.colorScheme.outlineVariant,
                    ),
                    itemBuilder: (context, index) {
                      final model = filtered[index];
                      final isSelected = model.qualifiedId == widget.selectedId;

                      return InkWell(
                        onTap: () => widget.onSelected(model),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          color: isSelected
                              ? colors.accent.withValues(alpha: 0.08)
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
                                        fontFamily: colors.mono,
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      model.providerName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurfaceVariant,
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
                                  color: colors.accent,
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
    );
  }
}
