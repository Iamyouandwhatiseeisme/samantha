import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:samantha/app/injection.dart';
import 'package:samantha/app/router.dart';
import 'package:samantha/features/connection_settings/data/connection_settings_repository.dart';
import 'package:samantha/features/project_selection/data/project_api.dart';

@RoutePage()
class ProjectSelectionScreen extends StatefulWidget {
  const ProjectSelectionScreen({super.key});

  @override
  State<ProjectSelectionScreen> createState() => _ProjectSelectionScreenState();
}

class _ProjectSelectionScreenState extends State<ProjectSelectionScreen> {
  final _api = getIt<ProjectApi>();
  final _repository = getIt<ConnectionSettingsRepository>();
  List<OpenCodeProject> _projects = [];
  OpenCodeProject? _selected;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
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
      final projects = await _api.getProjects(host);
      if (!mounted) return;
      setState(() {
        _projects = projects;
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
    if (_selected == null) return;
    await _repository.saveProjectPath(_selected!.worktree);
    if (!mounted) return;
    context.router.replace(const ChatRoute());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Repository')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Failed to load repositories',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadProjects,
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
    if (_projects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_off, size: 48),
              const SizedBox(height: 16),
              Text('No repositories found',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                'Make sure opencode is running and has discovered\nyour git repositories.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadProjects,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Choose a repository for opencode to work in:',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _projects.length,
            itemBuilder: (context, index) {
              final project = _projects[index];
              final selected = _selected == project;
              return ListTile(
                leading: const Icon(Icons.folder),
                title: Text(project.displayName),
                subtitle: Text(project.worktree,
                    style: const TextStyle(fontSize: 12)),
                trailing: selected
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                selected: selected,
                onTap: () => setState(() => _selected = project),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selected != null ? _continue : null,
                child: const Text('Continue'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
