import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // Paquete para la conectividad
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'pages/login.dart'; // Asegúrate de tener la página de login
import 'pages/create.dart'; // Asegúrate de tener la página de crear cuenta
import 'pages/clients.dart'; // Página de clientes (transportista)
import 'package:firebase_auth/firebase_auth.dart'; // Importa Firebase Auth


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
    _checkConnectivity(); // Verifica la conectividad al iniciar
  }

  // Función para verificar la conexión a Internet
  void _checkConnectivity() async {
    List<ConnectivityResult> results = await _connectivity.checkConnectivity();
    ConnectivityResult result =
        results.isNotEmpty ? results.first : ConnectivityResult.none;

    if (result == ConnectivityResult.none) {
      _showNoInternetDialog();
    } else {
      // Verificar si el usuario ya está autenticado
      _checkAuthentication();
    }
  }

  // Función para verificar la autenticación
  void _checkAuthentication() async {
    User? user = FirebaseAuth.instance.currentUser; // Verifica el usuario autenticado
    if (user != null) {
      // El usuario está autenticado, redirigir a ClientsPage
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.pushReplacementNamed(context, '/clients');
      });
    } else {
      // El usuario no está autenticado, redirigir a LoginPage
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
                  _checkConnectivity(); // Volver a verificar la conectividad
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
    _connectivitySubscription.cancel(); // Cancelar la suscripción cuando ya no sea necesario
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
