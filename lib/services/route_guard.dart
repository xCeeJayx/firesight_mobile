import 'package:flutter/material.dart';
import '../models/user_role.dart';
import '../login_screen.dart';
import '../main_navigation_screen.dart';
import 'auth_service.dart';

class RouteGuard {
  static const String routeLogin = '/login';
  static const String routeInspectorDashboard = '/inspector/dashboard';
  static const String routeRiskMappingDashboard = '/risk-mapping/dashboard';
  static const String routeAdminDashboard = '/admin/dashboard';
  static const String routePublicMap = '/public/map';

  /// Check whether a role is permitted to navigate to a target route
  static bool canAccessRoute(UserRole role, String route) {
    if (route == '/' || route == routeLogin) return true;

    switch (route) {
      case routeInspectorDashboard:
        return role == UserRole.stationOfficer || role == UserRole.fireInspector;
      case routeRiskMappingDashboard:
        return role == UserRole.stationOfficer || role == UserRole.communityRiskOfficer;
      case routeAdminDashboard:
        return role == UserRole.stationOfficer;
      case routePublicMap:
        return true; // Everyone can view the public map
      default:
        return false;
    }
  }

  /// Get the appropriate landing route for a role
  static String getLandingRoute(UserRole role) {
    return role.defaultRoute;
  }

  /// Returns user-friendly explanation when access is denied
  static String getAccessDeniedMessage(UserRole role, String targetRoute) {
    if (role == UserRole.fireInspector && targetRoute.contains('risk-mapping')) {
      return 'Access Denied: FSIC Fire Inspectors are restricted from accessing OLP Community Risk Mapping.';
    } else if (role == UserRole.communityRiskOfficer && targetRoute.contains('inspector')) {
      return 'Access Denied: OLP Community Risk Officers are restricted from accessing FSIC Inspections.';
    } else if (role == UserRole.publicGuest) {
      return 'Access Denied: Please sign in with an official BFP account to access staff modules.';
    } else {
      return 'Access Denied: You do not have permission to view this route.';
    }
  }

  /// Generate routes with dynamic Role Guard verification
  static Route<dynamic> generateRoute(RouteSettings settings, UserRole currentRole) {
    final routeName = settings.name ?? routeLogin;

    if (routeName == '/' || routeName == routeLogin) {
      return PageRouteBuilder(
        settings: settings,
        pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      );
    }

    // Resolve active role from route arguments, passed currentRole, or AuthService singleton
    UserRole effectiveRole = currentRole;
    if (settings.arguments is UserRole) {
      effectiveRole = settings.arguments as UserRole;
    } else if (AuthService().currentRole != UserRole.publicGuest) {
      effectiveRole = AuthService().currentRole;
    }

    if (!canAccessRoute(effectiveRole, routeName)) {
      final fallbackRoute = getLandingRoute(effectiveRole);
      final message = getAccessDeniedMessage(effectiveRole, routeName);

      return PageRouteBuilder(
        settings: RouteSettings(name: fallbackRoute),
        pageBuilder: (context, animation, secondaryAnimation) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(message)),
                  ],
                ),
                backgroundColor: const Color(0xFFDC2626),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
              ),
            );
          });
          return _buildScreenForRoute(fallbackRoute, effectiveRole);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      );
    }

    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) {
        return _buildScreenForRoute(routeName, effectiveRole);
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  static Widget _buildScreenForRoute(String routeName, UserRole role) {
    switch (routeName) {
      case routeLogin:
      case '/':
        return const LoginScreen();
      case routeInspectorDashboard:
        return const MainNavigationScreen(activeRole: UserRole.fireInspector);
      case routeRiskMappingDashboard:
        return const MainNavigationScreen(activeRole: UserRole.communityRiskOfficer);
      case routeAdminDashboard:
        return const MainNavigationScreen(activeRole: UserRole.stationOfficer);
      case routePublicMap:
        return const MainNavigationScreen(activeRole: UserRole.publicGuest);
      default:
        return const LoginScreen();
    }
  }
}
