import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'route.dart'; // Página de la ruta
import '../widgets/logout_button.dart'; // Cerrar cuenta??
import 'dart:async';
import 'dart:math';
import 'login.dart';

class ClientsPage extends StatefulWidget {
  @override
  _ClientsPageState createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  GoogleMapController? mapController;
  LatLng? _currentLocation;
  bool isOnTrip = false; // Indica si el transportista está en un recorrido
  Set<Marker> _markers = {}; // Marcadores para el mapa

  final FirebaseAuth _auth = FirebaseAuth.instance;
  late String transportistaId;
  late String tripId; // ID del recorrido
  Timer? _locationUpdateTimer;

  // Lista para guardar el historial de ubicaciones durante el recorrido
  List<LatLng> tripLocations = [];

  // Variable para registrar la hora de inicio del recorrido
  late Timestamp tripStartTime;

  // Variables para manejar el control de tiempo y distancia
  LatLng? lastLocation; // Declara lastLocation como LatLng?
  DateTime? lastUpdateTime; // Declara lastUpdateTime como DateTime?

  final int moveThreshold = 5; // Distancia mínima para enviar (en metros)
  final int timeThreshold = 30; // Intervalo de tiempo (en segundos)

  @override
  void dispose() {
    // Finaliza el recorrido si la aplicación se cierra
    if (isOnTrip) {
      _endTrip();
    }

    // Cancela cualquier timer activo
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    transportistaId = _auth.currentUser?.uid ?? '';
    _checkIfOnTrip(); // Verificar si ya hay un recorrido en curso al iniciar la app
  }

  // Obtener la ubicación actual del transportista
  Future<void> _getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    print(
        "Ubicación actual: ${position.latitude}, ${position.longitude}"); // Verifica si se obtiene la ubicación
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
    });
  }

  // Verificar si ya hay un recorrido en curso
  Future<void> _checkIfOnTrip() async {
    // Consultar el recorrido en Firestore
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('recorridos')
        .where('transportistaId', isEqualTo: transportistaId)
        .where('isSharing', isEqualTo: true) // Solo busca recorridos activos
        .get();

    if (snapshot.docs.isNotEmpty) {
      // Si hay un recorrido activo
      DocumentSnapshot doc = snapshot.docs.first;
      setState(() {
        tripId = doc.id;
        isOnTrip = true;
        tripStartTime = doc['tripStart'];
      });
    }
  }

  // Función para mostrar alerta antes de comenzar a compartir la ubicación
  void _showLocationAlert() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Confirmar ubicación'),
          content: Text(
              'Estás a punto de comenzar el recorrido. Tu ubicación será visible para los pasajeros. ¿Estás seguro de que deseas continuar?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Cierra el diálogo sin hacer nada
              },
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Cierra el diálogo
                _startTrip(); // Comienza el recorrido y comparte la ubicación
              },
              child: Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }

  // Función para comenzar el recorrido (compartir ubicación)
  void _startTrip() {
    setState(() {
      isOnTrip = true;
      tripStartTime = Timestamp.now(); // Guarda la hora de inicio
      tripLocations = []; // Inicializa el historial de ubicaciones
    });

    // Crear un ID único para el recorrido
    tripId = FirebaseFirestore.instance.collection('recorridos').doc().id;

    // Inicia la actualización de ubicación en tiempo real en Firestore
    if (_currentLocation != null) {
      FirebaseFirestore.instance.collection('recorridos').doc(tripId).set({
        'transportistaId': transportistaId, //Para saber quien es el conductor
        'locations': [
          {
            'latitude': _currentLocation?.latitude,
            'longitude': _currentLocation?.longitude,
          }
        ], // Almacena la ubicación inicial
        'tripStart': tripStartTime,
        'tripEnd': null, // Inicialmente no hay fin
        'isSharing': true, // Marca que está compartiendo la ubicación
        'lastUpdated': Timestamp.now(),
      });

      // Actualizar el marcador en el mapa
      _markers.add(Marker(
        markerId: MarkerId('transportista'),
        position: _currentLocation!,
        infoWindow: InfoWindow(title: "Tu Ubicación"),
      ));

      // Actualizar el mapa
      if (mapController != null) {
        mapController
            ?.animateCamera(CameraUpdate.newLatLngZoom(_currentLocation!, 20));
      }
    }
    // Iniciar la actualización de ubicación cada 30 segundos
    _locationUpdateTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _updateTripLocation();
    });
  }

  // Función para finalizar el recorrido (dejar de compartir ubicación)
  void _endTrip() {
    setState(() {
      isOnTrip = false;
    });

    // Detener el Timer
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;

    // Detener la actualización de la ubicación en Firestore
    FirebaseFirestore.instance.collection('recorridos').doc(tripId).update({
      'isSharing': false, // Deja de compartir la ubicación
      'tripEnd': Timestamp.now(), // Guardamos el tiempo de finalización
    });

    setState(() {
      _markers
          .clear(); // Limpiar los marcadores del mapa cuando se deje de compartir la ubicación
    });
  }

  // Función para actualizar el historial de ubicaciones en tiempo real
  void _updateTripLocation() async {
    if (isOnTrip) {
      // Obtener la ubicación actual
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      LatLng newLocation = LatLng(position.latitude, position.longitude);

      // Verifica si hay movimiento
      // Si la ubicación ha cambiado más de 5 metros o ha pasado 30 segundos
      if (_shouldUpdateLocation(newLocation)) {
        setState(() {
          _currentLocation = newLocation;
          tripLocations.add(newLocation);

          // Actualizar el marcador en el mapa
          _markers.removeWhere(
              (marker) => marker.markerId.value == 'transportista');
          _markers.add(Marker(
            markerId: MarkerId('transportista'),
            position: newLocation,
            infoWindow: InfoWindow(title: "Tu ubicación"),
            //icon: BitmapDescriptor.defaultMarker,
          ));

          // Actualiza la cámara para seguir al transportista
          if (mapController != null) {
            mapController
                ?.animateCamera(CameraUpdate.newLatLngZoom(newLocation, 16));
          }
        });

        // Actualiza la ubicación en Firestore
        FirebaseFirestore.instance.collection('recorridos').doc(tripId).update({
          'locations': FieldValue.arrayUnion([
            {
              'latitude': newLocation.latitude,
              'longitude': newLocation.longitude
            }
          ]),
          'lastUpdated': Timestamp.now(),
        });

        // Actualiza la última ubicación y hora
        lastLocation = newLocation;
        lastUpdateTime = DateTime.now();

        print('Ubicación actualizada: $newLocation');
      } else {
        // Reiniciar el temporizador cada vez que no se detecte movimiento
        print('No se detectó movimiento, reiniciando temporizador...');
        _locationUpdateTimer?.cancel();
        _locationUpdateTimer = Timer.periodic(Duration(seconds: 30), (timer) {
          _updateTripLocation();
        });
      }
    }
  }

  bool _shouldUpdateLocation(LatLng newLocation) {
    if (lastLocation == null || lastUpdateTime == null) {
      return true; // actualiza si no hay ubicación previa
    }

    // Verificar si se ha movido más de 5 metros desde la última ubicación
    double distance = _getDistance(lastLocation!, newLocation);

    return distance >= moveThreshold;
  }

  // Función para calcular la distancia entre dos coordenadas (en metros)
  double _getDistance(LatLng start, LatLng end) {
    const double R = 6371e3; // Radio de la Tierra en metros
    final double lat1 = start.latitude * pi / 180;
    final double lat2 = end.latitude * pi / 180;
    final double deltaLat = (end.latitude - start.latitude) * pi / 180;
    final double deltaLon = (end.longitude - start.longitude) * pi / 180;

    final double a = (sin(deltaLat / 2) * sin(deltaLat / 2)) +
        (cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2));
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c; // Distancia en metros
  }

  void _logout() async {
    if (isOnTrip) {
      // Mostrar advertencia si intenta cerrar sesión mientras está en un recorrido
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('No puedes cerrar sesión'),
            content:
                Text('Debes finalizar el recorrido antes de cerrar tu cuenta.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Cierra el diálogo
                },
                child: Text('Aceptar'),
              ),
            ],
          );
        },
      );
    } else {
      try {
        // Obtener el ID del usuario
        String userId = FirebaseAuth.instance.currentUser!.uid;

        // Actualizar el campo 'isLoggedIn' a false en Firestore
        await FirebaseFirestore.instance
            .collection('clients')
            .doc(userId)
            .update({
          'isLoggedIn': false,
        });

        // Cerrar sesión en Firebase
        await _auth.signOut();

        // Redirigir al login utilizando la ruta configurada
        Navigator.pushReplacementNamed(context, '/login');
      } catch (e) {
        // Si ocurre un error, mostrar un mensaje de error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cerrar sesión: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Actualizamos la ubicación cada 30 segundos si está en un recorrido
    if (isOnTrip) {
      _updateTripLocation();
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Panel de Transportista'),
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: _logout, // Llama al método de logout
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _currentLocation == null
                ? Center(child: CircularProgressIndicator())
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _currentLocation ?? LatLng(0, 0),
                      zoom: 14,
                    ),
                    onMapCreated: (GoogleMapController controller) {
                      mapController = controller;
                      print("Mapa creado");
                    },
                    markers: _markers,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: isOnTrip ? _endTrip : _showLocationAlert,
                  child: Text(
                      isOnTrip ? 'Finalizar Recorrido' : 'Comenzar Recorrido'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOnTrip ? Colors.red : Colors.green,
                  ),
                ),
                // Botón para ver el recorrido de las rutas hechas
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RoutePage(
                            transportistaId:
                                transportistaId), // Pasamos el ID del transportista
                      ),
                    );
                  },
                  child: Text('Ver mi recorrido'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
