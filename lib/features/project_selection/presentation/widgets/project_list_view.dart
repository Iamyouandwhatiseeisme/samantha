import 'package:flutter/material.dart';
import 'package:samantha/common/extensions/context_x.dart';
import 'package:samantha/features/project_selection/data/project_api.dart';

class ProjectListView extends StatelessWidget {
  final List<OpenCodeProject> projects;
  final OpenCodeProject? selectedProject;
  final ValueChanged<OpenCodeProject> onSelectProject;
  final VoidCallback onRefresh;
  final String? searchQuery;

  const ProjectListView({
    required this.projects,
    required this.selectedProject,
    required this.onSelectProject,
    required this.onRefresh,
    this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) {
      final isSearching = searchQuery != null && searchQuery!.isNotEmpty;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isSearching ? Icons.search_off : Icons.folder_off, size: 48),
              const SizedBox(height: 16),
              Text(
                isSearching ? context.l10n.noResultsFound : context.l10n.noRepositoriesFound,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                isSearching
                    ? '${context.l10n.noResultsFound} "${searchQuery!}"'
                    : context.l10n.noRepositoriesDescription,
                textAlign: TextAlign.center,
              ),
              if (!isSearching) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: Text(context.l10n.refresh),
                ),
              ],
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
