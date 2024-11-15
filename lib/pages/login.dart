import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'create.dart'; // Página de creación de cuenta
import 'users.dart'; // Página de usuario
import 'clients.dart'; // Página de transportista

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _login() async {
    try {
      // Iniciar sesión con el correo y la contraseña proporcionados
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Obtener el ID del usuario
      String userId = userCredential.user!.uid;

      // verificacion en la colección 'users'
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        // Si el usuario se encuentra en 'users', redirigimos a la página de usuario
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => UserPage()), // Página de usuario
        );
      } else {
        // Si no se encuentra en 'users', verificamos en 'clients'
        userDoc = await _firestore.collection('clients').doc(userId).get();

        if (userDoc.exists) {
          // Si el usuario se encuentra en 'clients', redirigimos a la página de transportista
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => ClientsPage()), // Página de transportista
          );
        } else {
          // Si el usuario no se encuentra en ninguna colección
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Usuario no encontrado')),
          );
        }
      }
    } catch (e) {
      String message;
      if (e is FirebaseAuthException) {
        message = e.message ?? 'Error desconocido';
      } else {
        message = 'Error: ${e.toString()}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Iniciar Sesión'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Contraseña'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              child: Text('Iniciar Sesión'),
            ),
            SizedBox(height: 20),
            TextButton(
              onPressed: () {
                // Navegar a la página de creación de cuenta
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RegisterPage(), // Página de registro
                  ),
                );
              },
              child: Text('¿No tienes una cuenta? Regístrate aquí'),
            ),
          ],
        ),
      ),
    );
  }
}
