import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

class OpenCodeProject {
  final String id;
  final String worktree;

  const OpenCodeProject({required this.id, required this.worktree});

  factory OpenCodeProject.fromJson(Map<String, dynamic> json) {
    return OpenCodeProject(
      id: json['id'] as String? ?? '',
      worktree: json['worktree'] as String? ?? '',
    );
  }

  String get displayName {
    final parts = worktree.split('/');
    return parts.isNotEmpty ? parts.last : worktree;
  }
}

class OpenCodeSession {
  final String id;
  final String title;
  final String directory;
  final int createdAt;
  final double contextPercent;

  const OpenCodeSession({
    required this.id,
    required this.title,
    required this.directory,
    required this.createdAt,
    this.contextPercent = 0,
  });

  factory OpenCodeSession.fromJson(Map<String, dynamic> json) {
    final time = json['time'] as Map<String, dynamic>? ?? {};
    return OpenCodeSession(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      directory: json['directory'] as String? ?? '',
      createdAt: (time['created'] as num?)?.toInt() ?? 0,
      contextPercent: (json['contextPercent'] as num?)?.toDouble() ?? 0,
    );
  }

  String get displayName {
    if (title.isNotEmpty && title != 'Untitled') return title;
    final parts = directory.split('/');
    return parts.isNotEmpty ? parts.last : 'Session';
  }

  String get contextPercentStr {
    if (contextPercent <= 0) return '0%';
    if (contextPercent < 0.1) return '<0.1%';
    return '${contextPercent.toStringAsFixed(1)}%';
  }
}

@injectable
class ProjectApi {
  final Dio _dio;

  ProjectApi(this._dio);

  Future<List<OpenCodeProject>> getProjects(String host) async {
    final response = await _dio.get('http://$host:8383/projects');
    final body = response.data;
    final list = body is List ? body : (body['projects'] as List? ?? []);
    return list
        .map((j) => OpenCodeProject.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<List<OpenCodeSession>> getSessions(String host) async {
    final response = await _dio.get('http://$host:8383/sessions');
    final body = response.data;
    final list = body is List ? body : (body['sessions'] as List? ?? []);
    return list
        .map((j) => OpenCodeSession.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}
