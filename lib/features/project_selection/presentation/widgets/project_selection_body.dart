import 'package:flutter/material.dart';
import 'package:samantha/common/extensions/context_x.dart';
import 'package:samantha/features/project_selection/data/project_api.dart';
import 'package:samantha/features/project_selection/presentation/widgets/error_view.dart';
import 'package:samantha/features/project_selection/presentation/widgets/project_list_view.dart';
import 'package:samantha/features/project_selection/presentation/widgets/session_list_view.dart';
import 'package:samantha/features/project_selection/presentation/widgets/searchable_list.dart';

class ProjectSelectionBody extends StatelessWidget {
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onBackToSettings;
  final TabController tabController;
  final List<OpenCodeProject> projects;
  final OpenCodeProject? selectedProject;
  final void Function(OpenCodeProject) onSelectProject;
  final VoidCallback onRefresh;
  final List<OpenCodeSession> sessions;
  final OpenCodeSession? selectedSession;
  final void Function(OpenCodeSession) onSelectSession;
  final void Function(OpenCodeSession) onDeleteSession;
  final void Function(OpenCodeSession) onRenameSession;
  final VoidCallback onSubmit;
  final String projectSearchQuery;
  final String sessionSearchQuery;
  final ValueChanged<String> onProjectSearchChanged;
  final ValueChanged<String> onSessionSearchChanged;

  const ProjectSelectionBody({
    required this.loading,
    this.error,
    required this.onRetry,
    required this.onBackToSettings,
    required this.tabController,
    required this.projects,
    this.selectedProject,
    required this.onSelectProject,
    required this.onRefresh,
    required this.sessions,
    this.selectedSession,
    required this.onSelectSession,
    required this.onDeleteSession,
    required this.onRenameSession,
    required this.onSubmit,
    this.projectSearchQuery = '',
    this.sessionSearchQuery = '',
    required this.onProjectSearchChanged,
    required this.onSessionSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return ErrorView(
        message: error!,
        onRetry: onRetry,
        onBackToSettings: onBackToSettings,
      );
    }
    return Column(
      children: [
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: [
              SearchableList(
                searchHint: context.l10n.searchProjects,
                onSearchChanged: onProjectSearchChanged,
                child: ProjectListView(
                  projects: projects,
                  selectedProject: selectedProject,
                  onSelectProject: onSelectProject,
                  onRefresh: onRefresh,
                  searchQuery: projectSearchQuery.isEmpty ? null : projectSearchQuery,
                ),
              ),
              SearchableList(
                searchHint: context.l10n.searchSessions,
                onSearchChanged: onSessionSearchChanged,
                child: SessionListView(
                  sessions: sessions,
                  selectedSession: selectedSession,
                  onSelectSession: onSelectSession,
                  onRefresh: onRefresh,
                  onDeleteSession: onDeleteSession,
                  onRenameSession: onRenameSession,
                  searchQuery: sessionSearchQuery.isEmpty ? null : sessionSearchQuery,
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: Alignment.bottomCenter,
          child: tabController.index == 0
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                        child: ElevatedButton(
                        onPressed: selectedProject != null ? onSubmit : null,
                        child: Text(context.l10n.newSession),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
