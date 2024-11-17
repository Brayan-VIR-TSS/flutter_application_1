import 'package:flutter/material.dart';
import '../widgets/logout_button.dart'; // cerrar cuenta

class UserPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Página de Usuario'),
      actions: [
          LogoutButton(), // Botón de cerrar sesión
        ],
        ),
      body: Center(
        child: Text('¡Bienvenido a la página de usuarios!'),
      ),
    );
  }
}
