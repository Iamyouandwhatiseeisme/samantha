import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:samantha/app/injection.dart';
import 'package:samantha/app/router.dart';
import 'package:samantha/app/settings_wrapper.dart';
import 'package:samantha/app/theme.dart';
import 'package:samantha/common/extensions/context_x.dart';
import 'package:samantha/features/connection_settings/presentation/state/connection_settings_cubit.dart';
import 'package:samantha/features/connection_settings/presentation/state/connection_settings_state.dart';
import 'package:samantha/features/connection_settings/presentation/widgets/connection_test_result.dart';
import 'package:samantha/features/notification/data/notification_settings_repository.dart';
import 'package:samantha/features/notification/service/notification_service.dart';

@RoutePage()
class ConnectionSettingsScreen extends StatefulWidget {
  const ConnectionSettingsScreen({super.key});

  @override
  State<ConnectionSettingsScreen> createState() => _ConnectionSettingsScreenState();
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

  Future<void> _requestNotificationPermissionIfNeeded() async {
    final settingsRepo = getIt<NotificationSettingsRepository>();
    if (settingsRepo.hasPermissionBeenRequested()) return;

    if (!mounted) return;

    final shouldAsk = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.notificationPermissionTitle),
        content: Text(context.l10n.notificationPermissionMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    if (shouldAsk != true || !mounted) return;

    final notificationService = getIt<NotificationService>();
    final granted = await notificationService.requestPermission();

    if (!mounted) return;

    if (granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.notificationPermissionGranted),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _authTokenController.dispose();
    super.dispose();
  }

  void _showLanguagePicker(BuildContext context) {
    final current = context.selectedLocale;

    final languages = <({Locale? locale, String label, String flag})>[
      (locale: null, label: 'System', flag: '🌐'),
      (locale: const Locale('en'), label: 'English', flag: '🇬🇧'),
      (locale: const Locale('ka'), label: 'ქართული', flag: '🇬🇪'),
    ];

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: languages.map((lang) {
              final isSelected = current?.languageCode == lang.locale?.languageCode;
              return ListTile(
                leading: Text(lang.flag, style: const TextStyle(fontSize: 20)),
                title: Text(lang.label),
                trailing: isSelected ? const Icon(Icons.check, color: Colors.orange) : null,
                onTap: () {
                  context.setLocale(lang.locale);
                  Navigator.of(ctx).pop();
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);

    return BlocConsumer<ConnectionSettingsCubit, ConnectionSettingsState>(
      listener: (context, state) {
        if (state is ConnectionSettingsLoaded) {
          _syncFromState(state);
        }
        if (state is ConnectionSettingsTestSuccess) {
          _requestNotificationPermissionIfNeeded();
          context.router.push(const ProjectSelectionRoute());
        }
      },
      builder: (context, state) {
        _syncFromState(state);

        return Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.connectionSettings),
            actions: [
              IconButton(
                icon: const Icon(Icons.language, size: 20),
                onPressed: () => _showLanguagePicker(context),
              ),
              IconButton(
                icon: Icon(
                  context.themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
                  size: 20,
                ),
                onPressed: () => context.setThemeMode(
                  context.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
                ),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _hostController,
                  enabled: state is! ConnectionSettingsTesting,
                  decoration: InputDecoration(
                    labelText: context.l10n.hostTailscaleIp,
                    hintText: context.l10n.hostHint,
                  ),
                  onChanged: (v) => context.read<ConnectionSettingsCubit>().updateHost(v),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _authTokenController,
                  enabled: state is! ConnectionSettingsTesting,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: context.l10n.authToken,
                    hintText: context.l10n.authTokenHint,
                  ),
                  onChanged: (v) => context.read<ConnectionSettingsCubit>().updateAuthToken(v),
                ),
                const SizedBox(height: 16),
                ConnectionTestResult(state: state),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: BorderSide(color: theme.colorScheme.outline, width: 0.5),
                        ),
                        onPressed: state is! ConnectionSettingsTesting
                            ? () => context.read<ConnectionSettingsCubit>().testConnection(
                                _hostController.text.trim(),
                              )
                            : null,
                        child: state is ConnectionSettingsTesting
                            ? SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.accent,
                                ),
                              )
                            : Text(
                                context.l10n.testConnection,
                                style: TextStyle(
                                  fontFamily: colors.mono,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: state is ConnectionSettingsTesting
                            ? null
                            : () async {
                                final host = _hostController.text.trim();
                                final token = _authTokenController.text.trim();
                                if (host.isEmpty || token.isEmpty) return;

                                await context.read<ConnectionSettingsCubit>().save(host, token);
                                if (!context.mounted) return;

                                context.read<ConnectionSettingsCubit>().testConnection(host);
                              },
                        child: Text(
                          context.l10n.saveAndConnect,
                          style: TextStyle(
                            fontFamily: colors.mono,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

