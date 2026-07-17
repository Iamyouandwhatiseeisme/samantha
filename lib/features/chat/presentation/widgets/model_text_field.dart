import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:samantha/app/theme.dart';
import 'package:samantha/features/chat/presentation/state/chat_cubit.dart';
import 'package:samantha/features/chat/presentation/state/chat_state.dart';
import 'package:samantha/features/chat/presentation/widgets/model_picker_sheet.dart';

class _ModelPickerState {
  final List<ModelProvider> availableModels;
  final String? selectedModel;
  const _ModelPickerState({
    required this.availableModels,
    this.selectedModel,
  });
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

  List<FlatModel> _flatten(List<ModelProvider> providers) {
    final flat = <FlatModel>[];
    for (final provider in providers) {
      for (final model in provider.models) {
        flat.add(FlatModel(
          model.qualifiedId,
          model.displayName,
          provider.name,
        ));
      }
    }
    return flat;
  }

  String _labelFor(String? selectedId, List<FlatModel> all) {
    if (selectedId == null) return 'Select model';
    final match = all.where((m) => m.qualifiedId == selectedId);
    if (match.isEmpty) return selectedId.split('/').last;
    return match.first.displayName;
  }

  void _openSheet(List<FlatModel> allModels, String? selectedId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => ModelPickerSheet(
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

