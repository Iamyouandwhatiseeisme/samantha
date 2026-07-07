class ConnectionSettings {
  final String host;
  final int port;

  const ConnectionSettings({
    required this.host,
    required this.port,
  });

  static const defaultSettings = ConnectionSettings(
    host: '100.0.0.1',
    port: 8080,
  );

  String get wsUrl => 'ws://$host:$port';

  ConnectionSettings copyWith({
    String? host,
    int? port,
  }) {
    return ConnectionSettings(
      host: host ?? this.host,
      port: port ?? this.port,
    );
  }

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
      };

  factory ConnectionSettings.fromJson(Map<String, dynamic> json) =>
      ConnectionSettings(
        host: json['host'] as String,
        port: json['port'] as int,
      );
}
