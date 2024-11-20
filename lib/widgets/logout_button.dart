import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LogoutButton extends StatelessWidget {
  final VoidCallback? onLogout; // Callback para controlar el cierre de sesión

  const LogoutButton({Key? key, this.onLogout}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.logout),
      onPressed: () {
        if (onLogout != null) {
          onLogout!();
        }
      },
    );
  }
}
