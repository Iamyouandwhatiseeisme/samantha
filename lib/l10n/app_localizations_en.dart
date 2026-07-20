// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Samantha';

  @override
  String get tabRepository => 'Repository';

  @override
  String get tabSession => 'Session';

  @override
  String get newSession => 'New Session';

  @override
  String get failedToLoadData => 'Failed to load data';

  @override
  String get retry => 'Retry';

  @override
  String get backToSettings => 'Back to Settings';

  @override
  String get noRepositoriesFound => 'No repositories found';

  @override
  String get noRepositoriesDescription =>
      'Make sure opencode is running and has discovered\nyour git repositories.';

  @override
  String get refresh => 'Refresh';

  @override
  String get noPreviousSessions => 'No previous sessions';

  @override
  String get noSessionsDescription =>
      'Sessions from your opencode server\nwill appear here.';

  @override
  String get connectionSettings => 'Connection Settings';

  @override
  String get hostTailscaleIp => 'Host / Tailscale IP';

  @override
  String get hostHint => '100.101.102.103 or laptop.tailnet.ts.net';

  @override
  String get authToken => 'Auth Token';

  @override
  String get authTokenHint => 'Set by BRIDGE_AUTH_TOKEN env var';

  @override
  String get testConnection => 'Test Connection';

  @override
  String get saveAndConnect => 'Save & Connect';

  @override
  String get connectionSuccessful => 'Connection successful';

  @override
  String get permissionRequired => 'Permission Required';

  @override
  String get allowThisAction => 'Allow this action?';

  @override
  String get deny => 'Deny';

  @override
  String get allow => 'Allow';

  @override
  String get chat => 'Chat';

  @override
  String get messageHint => 'Message…';

  @override
  String get selectModel => 'Select Model';

  @override
  String get searchModels => 'Search models…';

  @override
  String get noModelsFound => 'No models found';

  @override
  String get statusConnected => 'connected';

  @override
  String get statusStreaming => 'streaming';

  @override
  String get statusConnecting => 'connecting';

  @override
  String get statusOffline => 'offline';

  @override
  String get retryButton => 'RETRY';

  @override
  String get thinking => 'Thinking…';

  @override
  String get thought => 'Thought';

  @override
  String thoughtWithDuration(String duration) {
    return 'Thought for $duration';
  }

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String todosDone(int doneCount, int totalCount) {
    return '$doneCount/$totalCount done';
  }

  @override
  String get jumpToLatest => 'Jump to latest';

  @override
  String get errorCouldNotReachServer => 'Could not reach the server';

  @override
  String get errorServerDidNotRespond => 'Server did not respond in time';

  @override
  String get errorInvalidAuthToken => 'Invalid auth token';

  @override
  String get errorEnterConnectionDetails =>
      'Please enter your connection details';

  @override
  String get errorCouldNotEstablishConnection =>
      'Could not establish connection';

  @override
  String get errorInvalidResponseFromServer =>
      'Received invalid response from server';

  @override
  String get errorConnectionLost => 'Connection lost';

  @override
  String get errorSomethingWentWrong =>
      'Something went wrong. Please try again.';

  @override
  String get minutesAgo => 'm ago';

  @override
  String get hoursAgo => 'h ago';

  @override
  String get daysAgo => 'd ago';

  @override
  String get code => 'code';

  @override
  String get selectModelFallback => 'Select model';

  @override
  String get fallbackSessionTitle => 'Chat';
}
