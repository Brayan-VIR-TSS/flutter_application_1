import 'package:flutter/material.dart';

class UserPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Página de Usuario')),
      body: Center(
        child: Text('¡Bienvenido a la página de usuarios!'),
      ),
    );
  }
}
