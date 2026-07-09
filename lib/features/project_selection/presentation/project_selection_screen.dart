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
        context.router.replace(const ConnectionSettingsRoute());
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
    } else if (_tabController.index == 1 && _selectedSession != null) {
      await _repository.saveProjectPath(_selectedSession!.directory);
      await _repository.saveSessionId(_selectedSession!.id);
    } else {
      return;
    }
    if (!mounted) return;
    context.router.replace(const ChatRoute());
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : Column(
              children: [
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildProjectList(), _buildSessionList()],
                  ),
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: _tabController.index == 0 ? 1.0 : 0.0,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 250),
                    offset: _tabController.index == 0 ? Offset.zero : const Offset(0, 1),
                    child: IgnorePointer(
                      ignoring: _tabController.index != 0,
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _selectedProject != null ? _continue : null,
                              child: const Text('New Session'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildError() {
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
              formatErrorMessage(_error!),
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.router.replace(const ConnectionSettingsRoute()),
              child: const Text('Back to Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectList() {
    if (_projects.isEmpty) {
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
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: _projects.length,
      itemBuilder: (context, index) {
        final project = _projects[index];
        final selected = _selectedProject == project;
        return ListTile(
          leading: const Icon(Icons.folder),
          title: Text(project.displayName),
          subtitle: Text(project.worktree, style: const TextStyle(fontSize: 12)),
          trailing: selected ? const Icon(Icons.check_circle, color: Colors.green) : null,
          selected: selected,
          onTap: () => setState(() {
            _selectedProject = project;
            _selectedSession = null;
          }),
        );
      },
    );
  }

  Widget _buildSessionList() {
    if (_sessions.isEmpty) {
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
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        final session = _sessions[index];
        final selected = _selectedSession == session;
        return ListTile(
          leading: const Icon(Icons.chat),
          title: Text(session.displayName),
          subtitle: Text(
            '${session.directory.split('/').last} \u2022 ${_formatDate(session.createdAt)}',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: selected ? const Icon(Icons.check_circle, color: Colors.green) : null,
          selected: selected,
          onTap: () {
            _selectedSession = session;
            _selectedProject = null;
            _continue();
          },
        );
      },
    );
  }

  String _formatDate(int timestamp) {
    if (timestamp == 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.month}/${date.day}';
  }
}
