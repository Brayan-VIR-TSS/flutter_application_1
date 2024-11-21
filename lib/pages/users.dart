import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/logout_button.dart'; // Cerrar cuenta
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http; // Para la distancia
import 'package:geolocator/geolocator.dart'; // Para la ubicación del usuario

class UserPage extends StatefulWidget {
  @override
  _UserPageState createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  late GoogleMapController mapController;
  LatLng _userLocation = LatLng(0, 0); // Ubicación inicial
  bool _isLoading =
      true; // Flag para mostrar un indicador de carga mientras solicitamos el permiso

  late Stream<QuerySnapshot> _streamTransportistas;
  final Set<Marker> _markers = {}; // Marcadores del mapa
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late String userId;

  // API Key de Google Maps
  final String _googleApiKey = "AIzaSyCeuj3D-wjMEv8kNXjb34HcTWfj85VT3o0";

  Set<Marker> transportistaMarkers = {}; // Marcadores para transportistas

  @override
  void initState() {
    super.initState();
    userId = _auth.currentUser?.uid ?? '';
    _streamTransportistas = FirebaseFirestore.instance
        .collection('recorridos')
        .where('isSharing', isEqualTo: true) // Filtrar transportistas activos
        .snapshots();
    _getUserLocation(); // Obtener ubicación del usuario al cargar la pantalla
  }

  Future<void> _getUserLocation() async {
    // Usamos Geolocator para obtener la ubicación con la API
    LocationSettings locationSettings = LocationSettings(
      accuracy:
          LocationAccuracy.high, // Aquí defines la precisión que necesitas
      distanceFilter:
          10, // Puedes definir una distancia mínima (en metros) para recibir una actualización
    );

    try {
      // Obtenemos la ubicación con los nuevos ajustes
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );

      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _isLoading =
            false; // Desactivamos el cargador una vez que la ubicación está lista
      });
    } catch (e) {
      print('Error al obtener la ubicación: $e');
      // Manejo de errores (por ejemplo, si la ubicación no está disponible o se deniega el permiso)
    }
  }

  // Función para obtener los datos del transportista desde la colección 'clients'
  Future<Map<String, String>> _getTransportistaDetails(
      String transportistaId) async {
    DocumentSnapshot transportistaDoc = await FirebaseFirestore.instance
        .collection('clients')
        .doc(transportistaId)
        .get();

    if (transportistaDoc.exists) {
      var transportistaData = transportistaDoc.data() as Map<String, dynamic>;
      return {
        'name': transportistaData['name'],
        'lastname': transportistaData['lastname'],
        'vehicle_plate': transportistaData['vehicle_plate'],
      };
    }
    return {}; // Si no se encuentran los datos
  }

  // Calcular el tiempo estimado usando la API de Google Distance Matrix
  Future<String> _getEstimatedTime(
      LatLng userLocation, LatLng transportistaLocation) async {
    final String origin = '${userLocation.latitude},${userLocation.longitude}';
    final String destination =
        '${transportistaLocation.latitude},${transportistaLocation.longitude}';

    final String url =
        'https://maps.googleapis.com/maps/api/distancematrix/json?origins=$origin&destinations=$destination&key=$_googleApiKey';

    final response = await http.get(Uri.parse(url));
    final Map<String, dynamic> data = json.decode(response.body);

    if (data['status'] == 'OK') {
      final String duration =
          data['rows'][0]['elements'][0]['duration']['text'];
      return duration;
    } else {
      return 'Desconocido'; // Si ocurre un error al obtener el tiempo
    }
  }

  // Función para crear los marcadores para los transportistas activos
  Set<Marker> _buildMarkers(List<DocumentSnapshot> transportistas) {
    Set<Marker> markers = {};

    for (var transportista in transportistas) {
      // Asegúrate de que el campo 'locations' contiene las ubicaciones del transportista
      var transportistaLocation =
          transportista['locations'][0]; // Tomamos la primera ubicación
      var transportistaPosition = LatLng(
        transportistaLocation['latitude'],
        transportistaLocation['longitude'],
      );

      var transportistaId = transportista['transportistaId'];

      // Obtenemos los datos del transportista
      _getTransportistaDetails(transportistaId).then((details) async {
        String name = details['name'] ?? 'Desconocido';
        String lastname = details['lastname'] ?? 'Desconocido';
        String vehiclePlate = details['vehicle_plate'] ?? 'Sin patente';
        String estimatedTime =
            await _getEstimatedTime(_userLocation, transportistaPosition);

        // Agregamos un marcador para cada transportista activo
        //info en pantalla
        markers.add(Marker(
          markerId: MarkerId(transportista.id),
          position: transportistaPosition,
          infoWindow: InfoWindow(
            title: 'Transportista $name $lastname',
            snippet: 'Patente: $vehiclePlate\nTiempo estimado: $estimatedTime',
          ),
        ));
      });
    }

    return markers;
  }

  // Función para cerrar sesión
  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(
        context, '/login'); // Redirigir al login después de cerrar sesión
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Usuarios - Transportistas Activos'),
        actions: [
          LogoutButton(onLogout: _logout), // Botón de cerrar sesión
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator()) // Cargando ubicación
          : StreamBuilder<QuerySnapshot>(
              stream: _streamTransportistas,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                var transportistas = snapshot.data!.docs;

                // Crear un conjunto de marcadores
                Set<Marker> transportistaMarkers = {};

                // Iterar sobre los transportistas y agregar los marcadores
                for (var transportista in transportistas) {
                  var transportistaLocation = transportista['locations']
                      [0]; // Tomamos la primera ubicación
                  var transportistaPosition = LatLng(
                    transportistaLocation['latitude'],
                    transportistaLocation['longitude'],
                  );

                  var transportistaId = transportista['transportistaId'];

                  // Obtener detalles del transportista
                  _getTransportistaDetails(transportistaId)
                      .then((details) async {
                    String name = details['name'] ?? 'Desconocido';
                    String lastname = details['lastname'] ?? 'Desconocido';
                    String vehiclePlate =
                        details['vehicle_plate'] ?? 'Sin patente';
                    String estimatedTime = await _getEstimatedTime(
                        _userLocation, transportistaPosition);

                    setState(() {
                      transportistaMarkers.add(Marker(
                        markerId: MarkerId(transportista.id),
                        position: transportistaPosition,
                        infoWindow: InfoWindow(
                          title: 'Transportista $name $lastname',
                          snippet:
                              'Patente: $vehiclePlate\nTiempo estimado: $estimatedTime',
                        ),
                      ));
                    });
                  });
                }

                return GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _userLocation,
                    zoom: 14,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    mapController = controller;
                  },
                  markers:
                      transportistaMarkers, // Los marcadores de transportistas activos
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                );
              },
            ),
    );
  }
}
