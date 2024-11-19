import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'route.dart'; // Página de la ruta
import '../widgets/logout_button.dart'; // Cerrar cuenta
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';


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

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    transportistaId = _auth.currentUser?.uid ?? '';
  }

  // Mostrar el diálogo de permiso de ubicación
  void _showLocationPermissionDialog() async {
    // Primero, verificamos si el permiso de ubicación está concedido
    PermissionStatus permissionStatus = await Permission.location.status;
    if (!permissionStatus.isGranted) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Permiso de Ubicación Necesario'),
            content: Text(
                'Para que esta aplicación funcione correctamente, necesitamos acceso a tu ubicación. Esto es necesario para poder compartir tu ubicación con los usuarios y realizar las funciones de GPS.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Cerrar el diálogo sin hacer nada
                },
                child: Text('Cancelar'),
              ),
              TextButton(
                onPressed: () async {
                  // Intentar obtener permiso
                  PermissionStatus status = await Permission.location.request();
                  if (status.isGranted) {
                    Navigator.pop(context); // Cerrar el diálogo
                    _getCurrentLocation(); // Obtener la ubicación
                  } else {
                    Navigator.pop(
                        context); // Cerrar el diálogo si el permiso no se concede
                    print("Permiso de ubicación denegado.");
                  }
                },
                child: Text('Aceptar'),
              ),
            ],
          );
        },
      );
    } else {
      // Si ya se ha concedido el permiso, obtenemos la ubicación
      _getCurrentLocation();
    }
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
      tripStartTime = Timestamp.now(); // Guardamos la hora de inicio
      tripLocations = []; // Inicializamos el historial de ubicaciones
    });

    // Crear un ID único para el recorrido
    tripId = FirebaseFirestore.instance.collection('recorridos').doc().id;

    // Inicia la actualización de ubicación en tiempo real en Firestore
    if (_currentLocation != null) {
      FirebaseFirestore.instance.collection('recorridos').doc(tripId).set({
        'transportistaId': transportistaId,
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
    // Iniciar la actualización de ubicación cada 5 segundos
  _locationUpdateTimer = Timer.periodic(Duration(seconds: 15), (timer) {
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
          .clear(); // Limpiar los marcadores del mapa cuando dejen de compartir la ubicación
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

    setState(() {
      _currentLocation = newLocation;

      // Añadir la nueva ubicación al historial
      tripLocations.add(newLocation);

      // Actualizar el marcador en el mapa
      _markers.removeWhere((marker) => marker.markerId.value == 'transportista');
      _markers.add(Marker(
        markerId: MarkerId('transportista'),
        position: newLocation,
        infoWindow: InfoWindow(title: "Tu ubicación"),
        icon: BitmapDescriptor.defaultMarker,
      ));
    });

    // Actualizar la ubicación en Firestore
    FirebaseFirestore.instance.collection('recorridos').doc(tripId).update({
      'locations': FieldValue.arrayUnion([
        {'latitude': newLocation.latitude, 'longitude': newLocation.longitude}
      ]),
      'lastUpdated': Timestamp.now(),
    });
  }
}


  @override
  Widget build(BuildContext context) {
    // Actualizamos la ubicación cada 5 segundos si está en un recorrido
    if (isOnTrip) {
      _updateTripLocation();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Panel de Transportista'),
        actions: [
          LogoutButton(), // Botón de cerrar sesión
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
                // Botón para ver el recorrido de la ruta
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
