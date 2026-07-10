import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:samantha/features/chat/presentation/state/chat_cubit.dart';
import 'package:samantha/features/chat/presentation/state/chat_state.dart';

class _TitleState {
  final ChatConnectionStatus connectionStatus;
  final String? currentProjectPath;
  const _TitleState({required this.connectionStatus, this.currentProjectPath});
}

class StatusDot extends StatelessWidget {
  const StatusDot({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ChatCubit, ChatState, _TitleState>(
      selector: (state) => _TitleState(
        connectionStatus: state.connectionStatus,
        currentProjectPath: state.currentProjectPath,
      ),
      builder: (context, titleState) {
        final (icon, color) = switch (titleState.connectionStatus) {
          ChatConnectionStatus.connected => (Icons.circle, Colors.green),
          ChatConnectionStatus.streaming => (Icons.circle, Colors.blue),
          ChatConnectionStatus.connecting => (Icons.sync, Colors.orange),
          ChatConnectionStatus.disconnected => (Icons.cloud_off, Colors.red),
        };

        final repoName = titleState.currentProjectPath?.split('/').last;

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 12),
              if (repoName != null) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    repoName,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
