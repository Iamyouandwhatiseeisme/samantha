import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:samantha/app/injection.dart';
import 'package:samantha/app/router.dart';
import 'package:samantha/features/chat/data/error_message.dart';
import 'package:samantha/features/connection_settings/data/connection_settings_repository.dart';
import 'package:samantha/features/project_selection/data/project_api.dart';

@RoutePage()
class ProjectSelectionScreen extends StatefulWidget {
  const ProjectSelectionScreen({super.key});

  @override
  State<ProjectSelectionScreen> createState() => _ProjectSelectionScreenState();
}

class _ProjectSelectionScreenState extends State<ProjectSelectionScreen>
    with SingleTickerProviderStateMixin {
  final _api = getIt<ProjectApi>();
  final _repository = getIt<ConnectionSettingsRepository>();
  late final TabController _tabController;

  List<OpenCodeProject> _projects = [];
  OpenCodeProject? _selectedProject;
  List<OpenCodeSession> _sessions = [];
  OpenCodeSession? _selectedSession;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)..addListener(() => setState(() {}));
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final host = await _repository.getHost();
      if (host == null || host.isEmpty) {
        if (!mounted) return;
        context.router.pop();
        return;
      }

      final results = await Future.wait([_api.getProjects(host), _api.getSessions(host)]);

      if (!mounted) return;
      setState(() {
        _projects = results[0] as List<OpenCodeProject>;
        _sessions = results[1] as List<OpenCodeSession>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _continue() async {
    if (_tabController.index == 0 && _selectedProject != null) {
      await _repository.saveProjectPath(_selectedProject!.worktree);
      await _repository.saveSessionId(null);
      await _repository.saveSessionName(_selectedProject!.displayName);
    } else if (_tabController.index == 1 && _selectedSession != null) {
      await _repository.saveProjectPath(_selectedSession!.directory);
      await _repository.saveSessionId(_selectedSession!.id);
      await _repository.saveSessionName(_selectedSession!.displayName);
      await _repository.saveLastActivity(_selectedSession!.lastActivity);
    } else {
      return;
    }
    if (!mounted) return;
    context.router.push(const ChatRoute());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Samantha'),
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: const [
            Tab(icon: Icon(Icons.folder), text: 'Repository'),
            Tab(icon: Icon(Icons.history), text: 'Session'),
          ],
        ),
      ),
      body: _BodyContent(
        loading: _loading,
        error: _error,
        onRetry: _loadData,
        onBackToSettings: () => context.router.pop(),
        tabController: _tabController,
        projects: _projects,
        selectedProject: _selectedProject,
        onSelectProject: (project) => setState(() {
          _selectedProject = project;
          _selectedSession = null;
        }),
        onRefresh: _loadData,
        sessions: _sessions,
        selectedSession: _selectedSession,
        onSelectSession: (session) {
          setState(() {
            _selectedSession = session;
            _selectedProject = null;
          });
          _continue();
        },
        onSubmit: _continue,
      ),
    );
  }

}

class _BodyContent extends StatelessWidget {
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
  final VoidCallback onSubmit;

  const _BodyContent({
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
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return _ErrorView(
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
              _ProjectListView(
                projects: projects,
                selectedProject: selectedProject,
                onSelectProject: onSelectProject,
                onRefresh: onRefresh,
              ),
              _SessionListView(
                sessions: sessions,
                selectedSession: selectedSession,
                onSelectSession: onSelectSession,
                onRefresh: onRefresh,
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
                        child: const Text('New Session'),
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

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBackToSettings;

  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.onBackToSettings,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text('Failed to load data', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              formatErrorMessage(message),
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onBackToSettings,
              child: const Text('Back to Settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectListView extends StatelessWidget {
  final List<OpenCodeProject> projects;
  final OpenCodeProject? selectedProject;
  final ValueChanged<OpenCodeProject> onSelectProject;
  final VoidCallback onRefresh;

  const _ProjectListView({
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

class _SessionListView extends StatelessWidget {
  final List<OpenCodeSession> sessions;
  final OpenCodeSession? selectedSession;
  final ValueChanged<OpenCodeSession> onSelectSession;
  final VoidCallback onRefresh;

  const _SessionListView({
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
              Text('No previous sessions', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                'Sessions from your opencode server\nwill appear here.',
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

