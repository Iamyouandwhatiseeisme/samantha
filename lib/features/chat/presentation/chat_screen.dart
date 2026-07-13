import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:samantha/app/theme_mode_cubit.dart';
import 'package:samantha/features/chat/presentation/state/chat_cubit.dart';
import 'package:samantha/features/chat/presentation/state/chat_state.dart';
import 'package:samantha/features/chat/presentation/widgets/error_banner.dart';
import 'package:samantha/features/chat/presentation/widgets/message_input.dart';
import 'package:samantha/features/chat/presentation/widgets/message_list.dart';
import 'package:samantha/features/chat/presentation/widgets/model_text_field.dart';
import 'package:samantha/features/chat/presentation/widgets/status_dot.dart';

@RoutePage()
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  late final _revealController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  static const double _maxReveal = 48.0;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatCubit>().connect();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  void _onRevealDragUpdate(DragUpdateDetails details) {
    _revealController.stop();
    _dragOffset += details.delta.dx;
    _dragOffset = _dragOffset.clamp(-_maxReveal, 0.0);
    _revealController.value = (-_dragOffset / _maxReveal).clamp(0.0, 1.0);
  }

  void _onRevealDragEnd(DragEndDetails details) {
    _revealController.reverse();
    _dragOffset = 0;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatCubit, ChatState>(
      listener: (context, state) {
        if (state.currentPermissionId != null) {
          _showPermissionDialog(context, state.currentPermissionTitle ?? '');
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              const _TopBar(),
              SizedBox(height: 16),
              const Divider(height: 1, thickness: 1),
              const SizedBox(height: 4),
              BlocBuilder<ChatCubit, ChatState>(
                builder: (context, state) {
                  if (state.errorMessage == null) return const SizedBox.shrink();
                  return ErrorBanner(message: state.errorMessage!);
                },
              ),
              Expanded(
                child: GestureDetector(
                  onHorizontalDragUpdate: _onRevealDragUpdate,
                  onHorizontalDragEnd: _onRevealDragEnd,
                  child: MessageList(
                    scrollController: _scrollController,
                    revealController: _revealController,
                    maxReveal: _maxReveal,
                  ),
                ),
              ),
              MessageInput(inputController: _inputController),
            ],
          ),
        ),
      ),
    );
  }

  void _showPermissionDialog(BuildContext context, String title) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Permission Required'),
        content: Text(title.isNotEmpty ? title : 'Allow this action?'),
        actions: [
          TextButton(
            onPressed: () {
              ctx.read<ChatCubit>().respondToPermission(false);
              Navigator.of(ctx).pop();
            },
            child: const Text('Deny'),
          ),
          FilledButton(
            onPressed: () {
              ctx.read<ChatCubit>().respondToPermission(true);
              Navigator.of(ctx).pop();
            },
            child: const Text('Allow'),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Row(
          children: [
            _IconButton(icon: Icons.arrow_back, onPressed: () => context.router.pop()),
            SizedBox(width: 8),
            Expanded(child: ModelTextField()),
            SizedBox(width: 8),
            const StatusDot(),
            const SizedBox(width: 8),
            BlocBuilder<ThemeModeCubit, ThemeMode>(
              builder: (context, themeMode) {
                return _IconButton(
                  icon: themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
                  onPressed: () => context.read<ThemeModeCubit>().toggle(),
                );
              },
            ),
            _IconButton(icon: Icons.refresh, onPressed: () => context.read<ChatCubit>().connect()),
          ],
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _IconButton({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      constraints: const BoxConstraints(minWidth: 36, maxWidth: 36, minHeight: 36, maxHeight: 36),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
    );
  }
}
