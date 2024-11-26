import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    userId = _auth.currentUser?.uid ?? '';
    _streamTransportistas = FirebaseFirestore.instance
        .collection('recorridos')
        .where('isSharing', isEqualTo: true) // Filtrar transportistas activos
        .snapshots();
    _getUserLocation(); // Obtener ubicación del usuario al cargar la pantalla
    //_loadOfficialRoute(); // Cargar la ruta oficial
  }

  // Función para obtener la ruta oficial en tiempo real
  Stream<List<LatLng>> _getOfficialRouteStream() {
    // Escuchar la colección 'official_route' en tiempo real
    return FirebaseFirestore.instance
        .collection('official_route')
        .where('isOfficial', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return []; // Si no hay rutas, retornamos una lista vacía
      }

      // Tomamos la primera ruta oficial (puedes adaptarlo si hay varias)
      final routeData = snapshot.docs.first.data();
      List<dynamic> locations = routeData['locations'];
      return locations
          .map(
              (location) => LatLng(location['latitude'], location['longitude']))
          .toList();
    });
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
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
    } catch (e) {
      print('Error al obtener la ubicación: $e');
    }
  }

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
      return 'Desconocido';
    }
  }

  Future<Map<String, String>> _getEstimatedTimeAndDistance(
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
      final String distance =
          data['rows'][0]['elements'][0]['distance']['text'];

      return {'duration': duration, 'distance': distance};
    } else {
      return {'duration': 'Desconocido', 'distance': 'Desconocido'};
    }
  }

  Future<void> _buildMarkers(List<DocumentSnapshot> transportistas) async {
    Set<Marker> markers = {};

    for (var transportista in transportistas) {
      var transportistaLocation =
          transportista['locations'][0]; // Tomamos la primera ubicación
      var transportistaPosition = LatLng(
        transportistaLocation['latitude'],
        transportistaLocation['longitude'],
      );
      var transportistaId = transportista['transportistaId'];

      Map<String, String> details =
          await _getTransportistaDetails(transportistaId);
      String name = details['name'] ?? 'Desconocido';
      String lastname = details['lastname'] ?? 'Desconocido';
      String vehiclePlate = details['vehicle_plate'] ?? 'Sin patente';

      // Obtener tanto la distancia como el tiempo estimado
      Map<String, String> timeAndDistance = await _getEstimatedTimeAndDistance(
          _userLocation, transportistaPosition);
      String estimatedTime = timeAndDistance['duration'] ?? 'Desconocido';
      String distance = timeAndDistance['distance'] ?? 'Desconocido';

      markers.add(Marker(
        markerId: MarkerId(transportista.id),
        position: transportistaPosition,
        infoWindow: InfoWindow(
          title: 'Transportista $name $lastname',
          snippet:
              'Patente: $vehiclePlate\nTiempo estimado: $estimatedTime\nDistancia: $distance',
        ),
        onTap: () async {
          // Cuando se haga clic en el marcador, obtener la ruta oficial
          _showOfficialRoute(transportistaId);
        },
      ));
    }

    setState(() {
      transportistaMarkers = markers;
    });
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _showOfficialRoute(String transportistaId) async {
    // Limpiar las rutas anteriores
    _polylines.clear();

    // Consultamos la colección "official_route" en Firestore para obtener la ruta oficial del transportista
    final snapshot = await FirebaseFirestore.instance
        .collection('official_route')
        .where('isOfficial', isEqualTo: true)
        .where('transportistaId', isEqualTo: transportistaId)
        .get();

    // Verificamos si encontramos una ruta oficial
    if (snapshot.docs.isNotEmpty) {
      final routeData = snapshot.docs.first.data();
      List<dynamic> locations = routeData['locations'];

      // Convertimos las coordenadas de la ruta oficial en una lista de LatLng
      List<LatLng> route = locations
          .map(
              (location) => LatLng(location['latitude'], location['longitude']))
          .toList();

      // Dibujamos la polilínea para mostrar la ruta en el mapa
      setState(() {
        _polylines.add(Polyline(
          polylineId: PolylineId('officialRoute_$transportistaId'),
          color: Colors.blue,
          width: 5,
          points: route,
        ));
      });
    } else {
      // Si no hay ruta oficial
      print("No se encontró una ruta oficial para este transportista.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Transportes Activos y Ruta Oficial'),
        actions: [
          LogoutButton(onLogout: _logout), // Botón de cerrar sesión
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: _streamTransportistas,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                var transportistas = snapshot.data!.docs;

                _buildMarkers(transportistas);

                return GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _userLocation,
                    zoom: 14,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    mapController = controller;
                  },
                  markers:
                      transportistaMarkers, // Marcadores de transportistas activos
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                );
              },
            ),
    );
  }
}
