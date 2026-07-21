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
  final String? parentId;
  final int inputTokens;
  final double cost;
  final double contextPercent;
  final String? lastActivity;

  const OpenCodeSession({
    required this.id,
    required this.title,
    required this.directory,
    required this.createdAt,
    this.parentId,
    this.inputTokens = 0,
    this.cost = 0,
    this.contextPercent = 0,
    this.lastActivity,
  });

  factory OpenCodeSession.fromJson(Map<String, dynamic> json) {
    final time = json['time'] as Map<String, dynamic>? ?? {};
    return OpenCodeSession(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      directory: json['directory'] as String? ?? '',
      createdAt: (time['created'] as num?)?.toInt() ?? 0,
      parentId: json['parent_id'] as String?,
      inputTokens: (json['inputTokens'] as num?)?.toInt() ?? 0,
      cost: (json['cost'] as num?)?.toDouble() ?? 0,
      contextPercent: (json['contextPercent'] as num?)?.toDouble() ?? 0,
      lastActivity: json['lastActivity'] as String?,
    );
  }

  String get displayName {
    if (title.isNotEmpty && title != 'Untitled') return title;
    final parts = directory.split('/');
    return parts.isNotEmpty ? parts.last : 'Session';
  }

  String get tokenCountStr {
    if (inputTokens >= 1000000) return '${(inputTokens / 1000000).toStringAsFixed(1)}M';
    if (inputTokens >= 1000) return '${(inputTokens / 1000).toStringAsFixed(1)}K';
    return inputTokens.toString();
  }

  String get costStr {
    if (cost <= 0) return '';
    if (cost < 0.01) return '<\$0.01';
    return '\$${cost.toStringAsFixed(2)}';
  }

  String get contextPctStr {
    if (contextPercent <= 0) return '';
    if (contextPercent < 0.1) return '<0.1%';
    return '${contextPercent.toStringAsFixed(1)}%';
  }

  bool get isBranch => parentId != null && parentId!.isNotEmpty;
}

class SessionTreeNode {
  final OpenCodeSession session;
  final int depth;
  final bool isLastInGroup;
  final bool hasChildren;

  const SessionTreeNode({
    required this.session,
    required this.depth,
    required this.isLastInGroup,
    required this.hasChildren,
  });
}

List<SessionTreeNode> buildSessionTree(List<OpenCodeSession> sessions) {
  final byId = <String, OpenCodeSession>{};
  final children = <String, List<OpenCodeSession>>{};
  final roots = <OpenCodeSession>[];

  for (final s in sessions) {
    byId[s.id] = s;
  }

  for (final s in sessions) {
    if (s.isBranch && byId.containsKey(s.parentId)) {
      children.putIfAbsent(s.parentId!, () => []).add(s);
    } else {
      roots.add(s);
    }
  }

  for (final childList in children.values) {
    childList.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }
  roots.sort((a, b) => a.createdAt.compareTo(b.createdAt));

  final result = <SessionTreeNode>[];

  void addNode(OpenCodeSession session, int depth, bool isLastInGroup) {
    final childList = children[session.id] ?? [];
    result.add(SessionTreeNode(
      session: session,
      depth: depth,
      isLastInGroup: isLastInGroup,
      hasChildren: childList.isNotEmpty,
    ));
    for (int i = 0; i < childList.length; i++) {
      addNode(childList[i], depth + 1, i == childList.length - 1);
    }
  }

  for (int i = 0; i < roots.length; i++) {
    addNode(roots[i], 0, i == roots.length - 1);
  }

  return result;
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
