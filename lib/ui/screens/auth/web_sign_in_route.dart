import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/ui/screens/auth/sign_in_screen.dart';

/// Returns web users to the page they requested after authentication.
class WebSignInRoute extends StatefulWidget {
  const WebSignInRoute({
    super.key,
    required this.initialSignUp,
    required this.returnTo,
  });

  final bool initialSignUp;
  final String returnTo;

  @override
  State<WebSignInRoute> createState() => _WebSignInRouteState();
}

class _WebSignInRouteState extends State<WebSignInRoute> {
  StreamSubscription<AuthState>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      if (state.session != null && mounted) context.go(widget.returnTo);
    });
    if (Supabase.instance.client.auth.currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(widget.returnTo);
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SignInScreen(initialSignUp: widget.initialSignUp);
}
