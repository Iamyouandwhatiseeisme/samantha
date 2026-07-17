import 'package:flutter/material.dart';
import 'package:samantha/features/project_selection/data/project_api.dart';

class ProjectListView extends StatelessWidget {
  final List<OpenCodeProject> projects;
  final OpenCodeProject? selectedProject;
  final ValueChanged<OpenCodeProject> onSelectProject;
  final VoidCallback onRefresh;

  const ProjectListView({
    required this.projects,
    required this.selectedProject,
    required this.onSelectProject,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_off, size: 48),
              const SizedBox(height: 16),
              Text('No repositories found', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                'Make sure opencode is running and has discovered\nyour git repositories.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];
        final selected = selectedProject == project;
        return ListTile(
          leading: const Icon(Icons.folder),
          title: Text(project.displayName),
          subtitle: Text(project.worktree, style: const TextStyle(fontSize: 12)),
          trailing: selected ? const Icon(Icons.check_circle, color: Colors.green) : null,
          selected: selected,
          onTap: () => onSelectProject(project),
        );
      },
    );
  }
}
