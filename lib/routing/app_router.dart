import 'package:flutter/material.dart';
import 'package:safe_voice/routing/route_paths.dart';
import 'package:safe_voice/views/views.dart';
import 'package:safe_voice/widgets/widgets.dart';

/// Centralized router. Use named navigation throughout the app.
class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RoutePaths.onboarding:
        return _build(settings, const OnboardingScreen());
      case RoutePaths.shell:
        return _build(settings, const MainShell());
      case RoutePaths.emergencyExit:
        return _build(settings, const EmergencyExitScreen());
      // Deep linking to specific tab: pass desired index in arguments or map route to index.
      case RoutePaths.home:
        return _build(settings, const MainShell(initialIndex: 0));
      case RoutePaths.report:
        return _build(settings, const MainShell(initialIndex: 1));
      case RoutePaths.learn:
        return _build(settings, const MainShell(initialIndex: 2));
      case RoutePaths.settings:
        return _build(settings, const MainShell(initialIndex: 3));
      default:
        return _build(
          settings,
          Scaffold(
            body: Center(
              child: Text('Route not found: ${settings.name}'),
            ),
          ),
        );
    }
  }

  static PageRoute _build(RouteSettings s, Widget child) => MaterialPageRoute(settings: s, builder: (_) => child);
}

/// Shell widget that hosts bottom navigation and maintains state of tabs.
class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;

  final _navigatorKeys = List.generate(4, (_) => GlobalKey<NavigatorState>());

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTap(int index) {
    if (index == _currentIndex) {
      // Pop to first route in that tab's stack if already selected
      _navigatorKeys[index].currentState?.popUntil((r) => r.isFirst);
    } else {
      setState(() => _currentIndex = index);
    }
  }

  Widget _buildTabNavigator(int index, Widget child) {
    return Offstage(
      offstage: _currentIndex != index,
      child: Navigator(
        key: _navigatorKeys[index],
        onGenerateRoute: (routeSettings) => MaterialPageRoute(
          builder: (_) => child,
          settings: routeSettings,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final NavigatorState currentTabNav = _navigatorKeys[_currentIndex].currentState!;
        if (currentTabNav.canPop()) {
          currentTabNav.pop();
          return false;
        }
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return false;
        }
        return true; // allow system back to close app
      },
      child: Scaffold(
        body: Stack(
          children: [
            _buildTabNavigator(0, const HomeScreen()),
            _buildTabNavigator(1, const ReportCaseScreen(showBack: false)),
            _buildTabNavigator(2, const LearnScreen(showBack: false)),
            _buildTabNavigator(3, const SettingsScreen(showBack: false)),
          ],
        ),
        bottomNavigationBar: CustomNavBar(
          currentIndex: _currentIndex,
            onTap: _onTap,
        ),
      ),
    );
  }
}
