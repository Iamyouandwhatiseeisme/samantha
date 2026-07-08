import 'package:auto_route/auto_route.dart';
import 'package:samantha/features/chat/presentation/chat_screen.dart';
import 'package:samantha/features/connection_settings/presentation/connection_settings_screen.dart';
import 'package:samantha/features/project_selection/presentation/project_selection_screen.dart';

part 'router.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Screen,Route')
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
        AutoRoute(page: ConnectionSettingsRoute.page, initial: true),
        AutoRoute(page: ProjectSelectionRoute.page),
        AutoRoute(page: ChatRoute.page),
      ];
}
