import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Prefer in-app history. Falls back to [fallback] when the stack is empty.
void popOrGo(BuildContext context, String fallback) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go(fallback);
}

/// Push member routes so Android/iOS back returns to the previous screen.
void pushApp(BuildContext context, String location) {
  context.push(location);
}

/// True when [path] is one of the five bottom-bar destinations.
bool isPrimaryMemberTab(String path) {
  return path == '/app' ||
      path == '/app/discover' ||
      path.startsWith('/app/matches') ||
      path.startsWith('/app/messages') ||
      path.startsWith('/app/profile');
}

/// Handle system back inside the member shell without dumping the user out of the app.
/// Returns true when the event was handled in-app.
bool handleMemberBack(BuildContext context) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
    return true;
  }
  if (context.canPop()) {
    context.pop();
    return true;
  }
  final path = GoRouterState.of(context).uri.path;
  if (path != '/app' && path.startsWith('/app')) {
    context.go('/app');
    return true;
  }
  return false;
}
