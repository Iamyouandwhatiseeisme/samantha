sealed class ConnectionSettingsState {}

class ConnectionSettingsInitial extends ConnectionSettingsState {}

class ConnectionSettingsLoading extends ConnectionSettingsState {}

class ConnectionSettingsLoaded extends ConnectionSettingsState {
  final String host;
  final String authToken;

  ConnectionSettingsLoaded({required this.host, required this.authToken});
}

class ConnectionSettingsTesting extends ConnectionSettingsState {
  final String host;
  final String authToken;

  ConnectionSettingsTesting({required this.host, required this.authToken});
}

class ConnectionSettingsTestSuccess extends ConnectionSettingsState {
  final String host;
  final String authToken;

  ConnectionSettingsTestSuccess({required this.host, required this.authToken});
}

class ConnectionSettingsTestFailure extends ConnectionSettingsState {
  final String host;
  final String authToken;
  final String message;

  ConnectionSettingsTestFailure({
    required this.host,
    required this.authToken,
    required this.message,
  });
}
