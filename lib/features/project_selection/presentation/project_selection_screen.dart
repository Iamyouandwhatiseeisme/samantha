import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:samantha/app/injection.dart';
import 'package:samantha/app/router.dart';
import 'package:samantha/common/extensions/context_x.dart';
import 'package:samantha/features/connection_settings/data/connection_settings_repository.dart';
import 'package:samantha/features/project_selection/data/project_api.dart';
import 'package:samantha/features/project_selection/presentation/widgets/project_selection_body.dart';

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

  Future<void> _deleteSession(OpenCodeSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete session'),
        content: Text('Are you sure you want to delete "${session.displayName}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final host = await _repository.getHost();
      if (host == null) return;
      await _api.deleteSession(host, session.id);
      if (!mounted) return;
      setState(() {
        _sessions.removeWhere((s) => s.id == session.id);
        if (_selectedSession?.id == session.id) {
          _selectedSession = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete session: $e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _renameSession(OpenCodeSession session) async {
    final controller = TextEditingController(text: session.title == 'Untitled' ? '' : session.title);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename session'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter new name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(ctx).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (result == null || result.isEmpty || !mounted) return;

    try {
      final host = await _repository.getHost();
      if (host == null) return;
      await _api.renameSession(host, session.id, result);
      if (!mounted) return;
      setState(() {
        final idx = _sessions.indexWhere((s) => s.id == session.id);
        if (idx != -1) {
          _sessions[idx] = OpenCodeSession(
            id: _sessions[idx].id,
            title: result,
            directory: _sessions[idx].directory,
            createdAt: _sessions[idx].createdAt,
            parentId: _sessions[idx].parentId,
            inputTokens: _sessions[idx].inputTokens,
            cost: _sessions[idx].cost,
            contextPercent: _sessions[idx].contextPercent,
            lastActivity: _sessions[idx].lastActivity,
          );
        }
        if (_selectedSession?.id == session.id) {
          _selectedSession = OpenCodeSession(
            id: _selectedSession!.id,
            title: result,
            directory: _selectedSession!.directory,
            createdAt: _selectedSession!.createdAt,
            parentId: _selectedSession!.parentId,
            inputTokens: _selectedSession!.inputTokens,
            cost: _selectedSession!.cost,
            contextPercent: _selectedSession!.contextPercent,
            lastActivity: _selectedSession!.lastActivity,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to rename session: $e'), behavior: SnackBarBehavior.floating),
      );
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
        title: Text(context.l10n.appName),
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: [
            Tab(icon: const Icon(Icons.folder), text: context.l10n.tabRepository),
            Tab(icon: const Icon(Icons.history), text: context.l10n.tabSession),
          ],
        ),
      ),
      body: ProjectSelectionBody(
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
        onDeleteSession: _deleteSession,
        onRenameSession: _renameSession,
        onSubmit: _continue,
      ),
    );
  }

}

