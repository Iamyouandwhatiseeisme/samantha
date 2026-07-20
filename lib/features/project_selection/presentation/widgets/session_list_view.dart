import 'package:flutter/material.dart';
import 'package:samantha/common/extensions/context_x.dart';
import 'package:samantha/features/project_selection/data/project_api.dart';

class SessionListView extends StatelessWidget {
  final List<OpenCodeSession> sessions;
  final OpenCodeSession? selectedSession;
  final ValueChanged<OpenCodeSession> onSelectSession;
  final VoidCallback onRefresh;

  const SessionListView({
    required this.sessions,
    required this.selectedSession,
    required this.onSelectSession,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.history, size: 48),
              const SizedBox(height: 16),
              Text(context.l10n.noPreviousSessions, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                context.l10n.noSessionsDescription,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.refresh),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        final selected = selectedSession == session;
        return ListTile(
          leading: const Icon(Icons.chat),
          title: Text(session.displayName),
          subtitle: Text(
            '${session.directory.split('/').last} \u2022 ${session.tokenCountStr} tokens${session.cost > 0 ? ' \u2022 ${session.costStr}' : ''}${session.contextPercent > 0 ? ' \u2022 ${session.contextPctStr}' : ''}',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: selected ? const Icon(Icons.check_circle, color: Colors.green) : null,
          selected: selected,
          onTap: () => onSelectSession(session),
        );
      },
    );
  }
}
