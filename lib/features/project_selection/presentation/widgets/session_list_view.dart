import 'package:flutter/material.dart';
import 'package:samantha/common/extensions/context_x.dart';
import 'package:samantha/features/project_selection/data/project_api.dart';

class SessionListView extends StatelessWidget {
  final List<OpenCodeSession> sessions;
  final OpenCodeSession? selectedSession;
  final ValueChanged<OpenCodeSession> onSelectSession;
  final VoidCallback onRefresh;
  final ValueChanged<OpenCodeSession>? onDeleteSession;
  final ValueChanged<OpenCodeSession>? onRenameSession;
  final String? searchQuery;

  const SessionListView({
    required this.sessions,
    required this.selectedSession,
    required this.onSelectSession,
    required this.onRefresh,
    this.onDeleteSession,
    this.onRenameSession,
    this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      final isSearching = searchQuery != null && searchQuery!.isNotEmpty;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isSearching ? Icons.search_off : Icons.history, size: 48),
              const SizedBox(height: 16),
              Text(
                isSearching ? context.l10n.noResultsFound : context.l10n.noPreviousSessions,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                isSearching
                    ? '${context.l10n.noResultsFound} "${searchQuery!}"'
                    : context.l10n.noSessionsDescription,
                textAlign: TextAlign.center,
              ),
              if (!isSearching) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: Text(context.l10n.refresh),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final tree = buildSessionTree(sessions);

    return ListView.builder(
      itemCount: tree.length,
      itemBuilder: (context, index) {
        final node = tree[index];
        final session = node.session;
        final selected = selectedSession == session;
        return _SessionTreeTile(
          node: node,
          selected: selected,
          onTap: () => onSelectSession(session),
          onDelete: onDeleteSession != null ? () => onDeleteSession!(session) : null,
          onRename: onRenameSession != null ? () => onRenameSession!(session) : null,
        );
      },
    );
  }
}

class _SessionTreeTile extends StatelessWidget {
  final SessionTreeNode node;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onRename;

  const _SessionTreeTile({
    required this.node,
    required this.selected,
    required this.onTap,
    this.onDelete,
    this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = node.session;
    final depth = node.depth;
    final isBranch = session.isBranch;

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
              : null,
        ),
        padding: EdgeInsets.only(left: depth * 20.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (depth > 0) ...[
                _BranchConnector(
                  isLast: node.isLastInGroup,
                  hasChildren: node.hasChildren,
                  depth: depth,
                ),
                const SizedBox(width: 8),
              ],
              Icon(
                isBranch ? Icons.call_split : Icons.chat_bubble_outline,
                size: 20,
                color: isBranch
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.displayName,
                      style: TextStyle(
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${session.directory.split('/').last} \u2022 ${session.tokenCountStr} tokens${session.cost > 0 ? ' \u2022 ${session.costStr}' : ''}${session.contextPercent > 0 ? ' \u2022 ${session.contextPctStr}' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (isBranch) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.fork_right,
                            size: 11,
                            color: theme.colorScheme.secondary.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Branched session',
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.secondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              if (onDelete != null || onRename != null)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  padding: EdgeInsets.zero,
                  itemBuilder: (context) => [
                    if (onRename != null)
                      const PopupMenuItem(
                        value: 'rename',
                        height: 36,
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Rename'),
                          ],
                        ),
                      ),
                    if (onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        height: 36,
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                  ],
                  onSelected: (value) {
                    if (value == 'rename') onRename?.call();
                    if (value == 'delete') onDelete?.call();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BranchConnector extends StatelessWidget {
  final bool isLast;
  final bool hasChildren;
  final int depth;

  const _BranchConnector({
    required this.isLast,
    required this.hasChildren,
    required this.depth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.outlineVariant.withValues(alpha: 0.4);

    return CustomPaint(
      size: const Size(16, 36),
      painter: _ConnectorPainter(
        color: color,
        isLast: isLast,
        hasChildren: hasChildren,
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  final Color color;
  final bool isLast;
  final bool hasChildren;

  _ConnectorPainter({required this.color, required this.isLast, required this.hasChildren});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final centerX = size.width / 2;
    final halfHeight = size.height / 2;

    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, halfHeight),
      paint,
    );

    canvas.drawLine(
      Offset(centerX, halfHeight),
      Offset(size.width, halfHeight),
      paint,
    );

    if (!isLast) {
      canvas.drawLine(
        Offset(centerX, halfHeight),
        Offset(centerX, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.isLast != isLast ||
        oldDelegate.hasChildren != hasChildren;
  }
}
