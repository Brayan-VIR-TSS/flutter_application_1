// logout_button.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LogoutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.logout),
      onPressed: () async {
        await FirebaseAuth.instance.signOut();
        Navigator.pushReplacementNamed(context, '/login'); // Redirigir al login después de cerrar sesión
      },
    );
  }
}

