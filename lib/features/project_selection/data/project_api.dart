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
}
