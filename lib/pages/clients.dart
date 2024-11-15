import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'route.dart'; // Página de la ruta

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

  // Obtener la ubicación actual del transportista
  Future<void> _getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
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

    // Inicia la actualización de ubicación en tiempo real en Firestore
    if (_currentLocation != null) {
      FirebaseFirestore.instance.collection('recorridos').add({
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
            ?.animateCamera(CameraUpdate.newLatLngZoom(_currentLocation!, 14));
      }
    }
  }

  // Función para finalizar el recorrido (dejar de compartir ubicación)
  void _endTrip() {
    setState(() {
      isOnTrip = false;
    });

    // Detener la actualización de la ubicación en Firestore
    FirebaseFirestore.instance
        .collection('recorridos')
        .where('transportistaId', isEqualTo: transportistaId)
        .get()
        .then((snapshot) {
      snapshot.docs.forEach((doc) {
        FirebaseFirestore.instance.collection('recorridos').doc(doc.id).update({
          'isSharing': false, // Deja de compartir la ubicación
          'tripEnd': Timestamp.now(), // Guardamos el tiempo de finalización
        });
      });
    });

    setState(() {
      _markers
          .clear(); // Limpiar los marcadores del mapa cuando dejen de compartir la ubicación
    });
  }

  // Función para actualizar el historial de ubicaciones en tiempo real
  void _updateTripLocation() {
    if (isOnTrip && _currentLocation != null) {
      setState(() {
        // Añadir la nueva ubicación al historial
        tripLocations.add(_currentLocation!);

        // Actualizar la ubicación en Firestore en tiempo real en la colección 'recorridos'
        FirebaseFirestore.instance
            .collection('recorridos')
            .where('transportistaId', isEqualTo: transportistaId)
            .get()
            .then((snapshot) {
          snapshot.docs.forEach((doc) {
            // Aquí actualizamos el documento del recorrido
            FirebaseFirestore.instance
                .collection('recorridos')
                .doc(doc.id)
                .update({
              'locations': FieldValue.arrayUnion([
                {
                  'latitude': _currentLocation?.latitude,
                  'longitude': _currentLocation?.longitude,
                }
              ]),
              'lastUpdated': Timestamp.now(),
            });
          });
        });
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
      ),
      body: Column(
        children: [
          Expanded(
            child: _currentLocation == null
                ? Center(child: CircularProgressIndicator())
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _currentLocation!,
                      zoom: 14,
                    ),
                    onMapCreated: (GoogleMapController controller) {
                      mapController = controller;
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
