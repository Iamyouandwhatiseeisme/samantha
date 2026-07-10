import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:samantha/app/router.dart';
import 'package:samantha/features/chat/data/error_message.dart';
import 'package:samantha/features/connection_settings/presentation/state/connection_settings_cubit.dart';
import 'package:samantha/features/connection_settings/presentation/state/connection_settings_state.dart';

@RoutePage()
class ConnectionSettingsScreen extends StatefulWidget {
  const ConnectionSettingsScreen({super.key});

  @override
  State<ConnectionSettingsScreen> createState() =>
      _ConnectionSettingsScreenState();
}

class _ConnectionSettingsScreenState extends State<ConnectionSettingsScreen> {
  final _hostController = TextEditingController();
  final _authTokenController = TextEditingController();
  bool _initialized = false;

  void _syncFromState(ConnectionSettingsState state) {
    switch (state) {
      case ConnectionSettingsLoaded(:final host, :final authToken):
      case ConnectionSettingsTesting(:final host, :final authToken):
      case ConnectionSettingsTestSuccess(:final host, :final authToken):
      case ConnectionSettingsTestFailure(:final host, :final authToken):
        if (!_initialized) {
          _hostController.text = host;
          _authTokenController.text = authToken;
          _initialized = true;
        }
      default:
        break;
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _authTokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConnectionSettingsCubit, ConnectionSettingsState>(
      listener: (context, state) {
        if (state is ConnectionSettingsLoaded) {
          _syncFromState(state);
        }
        if (state is ConnectionSettingsTestSuccess) {
          context.router.push(const ProjectSelectionRoute());
        }
      },
      builder: (context, state) {
        _syncFromState(state);

        return Scaffold(
          appBar: AppBar(title: const Text('Connection Settings')),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _hostController,
                  enabled: state is! ConnectionSettingsTesting,
                  decoration: const InputDecoration(
                    labelText: 'Host / Tailscale IP',
                    hintText: '100.101.102.103 or laptop.tailnet.ts.net',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) =>
                      context.read<ConnectionSettingsCubit>().updateHost(v),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _authTokenController,
                  enabled: state is! ConnectionSettingsTesting,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Auth Token',
                    hintText: 'Set by BRIDGE_AUTH_TOKEN env var',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) =>
                      context.read<ConnectionSettingsCubit>().updateAuthToken(v),
                ),
                const SizedBox(height: 16),
                _TestResultWidget(state: state),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: state is! ConnectionSettingsTesting
                            ? () => context
                                .read<ConnectionSettingsCubit>()
                                .testConnection(_hostController.text.trim())
                            : null,
                        child: state is ConnectionSettingsTesting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Test Connection'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: state is ConnectionSettingsTesting
                            ? null
                            : () async {
                                final host = _hostController.text.trim();
                                final token = _authTokenController.text.trim();
                                if (host.isEmpty || token.isEmpty) return;

                                await context
                                    .read<ConnectionSettingsCubit>()
                                    .save(host, token);
                                if (!context.mounted) return;

                                context
                                    .read<ConnectionSettingsCubit>()
                                    .testConnection(host);
                              },
                        child: const Text('Save & Connect'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TestResultWidget extends StatelessWidget {
  final ConnectionSettingsState state;

  const _TestResultWidget({required this.state});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return switch (state) {
      ConnectionSettingsTestSuccess() => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.primary.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Connection successful',
                style: TextStyle(color: colorScheme.onPrimaryContainer),
              ),
            ],
          ),
        ),
      ConnectionSettingsTestFailure(:final message) => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.error.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline, size: 20, color: colorScheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  formatErrorMessage(message),
                  style: TextStyle(color: colorScheme.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      _ => const SizedBox.shrink(),
    };
  }
}
