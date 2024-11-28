import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // Paquete para la conectividad
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'pages/login.dart'; // página de login
import 'pages/create.dart'; // página de crear cuenta
import 'pages/clients.dart'; // Página de clientes (transportistas)
import 'pages/users.dart'; //Pagina de pasajeros (usuarios)
import 'package:firebase_auth/firebase_auth.dart'; // Importa Firebase Auth
import 'package:cloud_firestore/cloud_firestore.dart'; // Importa Firestore

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App de Transportista',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/splash', // La ruta inicial
      routes: {
        '/splash': (context) => SplashScreen(),
        '/login': (context) => LoginPage(),
        '/create': (context) => RegisterPage(),
        '/clients': (context) => ClientsPage(),
        '/users': (context) => UserPage(), // Ruta para pasajeros
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
    _checkAuthentication(); // Verifica la conectividad al iniciar
  }

  // Función para verificar la conexión a Internet
  void _checkAuthentication() async {
    User? user =
        FirebaseAuth.instance.currentUser; // Verifica el usuario autenticado
    if (user != null) {
      // El usuario está autenticado, ahora verificamos si es un transportista o un pasajero
      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection(
              'users') // Verifica si está en la colección de usuarios (pasajeros)
          .doc(user.uid)
          .get();

      if (userSnapshot.exists) {
        // Si el documento existe en "users", es un pasajero
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.pushReplacementNamed(context,
              '/users'); // Redirige a la página de pasajeros (cambia '/users' a la ruta correcta)
        });
      } else {
        // Si no existe en "users", verificamos en "clients" para transportistas
        DocumentSnapshot clientSnapshot = await FirebaseFirestore.instance
            .collection(
                'clients') // Verifica si está en la colección de transportistas
            .doc(user.uid)
            .get();

        if (clientSnapshot.exists) {
          // Si el documento existe en "clients", es un transportista
          Future.delayed(const Duration(seconds: 2), () {
            Navigator.pushReplacementNamed(
                context, '/clients'); // Redirige a la página de transportistas
          });
        } else {
          // Si no está en ninguna de las dos colecciones, redirige al login (por seguridad)
          Future.delayed(const Duration(seconds: 2), () {
            Navigator.pushReplacementNamed(context, '/login');
          });
        }
      }
    } else {
      // El usuario no está autenticado, redirige al LoginPage
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.pushReplacementNamed(context, '/login');
      });
    }
  }

  // Función que se llama cuando la conectividad cambia
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    // Tomamos el primer valor de la lista para saber el estado actual de la conectividad
    ConnectivityResult result =
        results.isNotEmpty ? results.first : ConnectivityResult.none;
    if (result == ConnectivityResult.none) {
      _showNoInternetDialog();
    } else {
      ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Oculta el snackBar
    }
  }

  // Mostrar un diálogo de alerta si no hay conexión a Internet
  void _showNoInternetDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sin Conexión a Internet'),
          content: const Text(
              'Por favor, revisa tu conexión a Internet y vuelve a intentarlo.'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                // Después de cerrar el diálogo, intentamos de nuevo conectar
                Future.delayed(const Duration(seconds: 2), () {
                  _checkAuthentication(); // Volver a verificar la conectividad
                });
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _connectivitySubscription
        .cancel(); // Cancelar la suscripción cuando ya no sea necesario
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 58, 116, 183),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const <Widget>[
            Icon(
              Icons.location_on,
              color: Colors.white,
              size: 100,
            ),
            SizedBox(height: 20),
            Text(
              'Mi App de GPS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
