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
  StreamSubscription<Position>? _positionStream;
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
    _startListeningToLocationChanges();
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

      // Tomamos la primera ruta oficial (se puede adaptar si hay mas¿'? )
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
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Metros
    );

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
      if (mounted) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
          _isLoading = false;
        });
      }
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
          data['rows'][0]['elements'][0]['duration']['text']; // Tiempo estimado
      final String distance =
          data['rows'][0]['elements'][0]['distance']['text']; // Distancia

      return {'duration': duration, 'distance': distance};
    } else {
      return {'duration': 'Desconocido', 'distance': 'Desconocido'};
    }
  }

  Future<void> _updatePolylines() async {
    if (transportistaMarkers.isNotEmpty) {
      for (var marker in transportistaMarkers) {
        // Obtén la posición del transportista desde sus marcadores
        LatLng transportistaLocation = marker.position;

        // Dibuja la ruta entre el usuario y cada transportista
        await _drawRoute(_userLocation, transportistaLocation);
      }
    }
  }

  Future<void> _drawRoute(
      LatLng userLocation, LatLng transportistaLocation) async {
    final String origin = '${userLocation.latitude},${userLocation.longitude}';
    final String destination =
        '${transportistaLocation.latitude},${transportistaLocation.longitude}';
    final String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&key=$_googleApiKey';

    final response = await http.get(Uri.parse(url));
    final Map<String, dynamic> data = json.decode(response.body);

    /*if (data['status'] == 'OK') {
      // Obtener las coordenadas de la ruta
      List<LatLng> route = [];
      for (var step in data['routes'][0]['legs'][0]['steps']) {
        var polyline = step['polyline']['points'];
        route.addAll(_decodePolyline(polyline));
      }*/

    if (data['status'] == 'OK') {
      // Limpiar la polilínea anterior antes de agregar una nueva
      setState(() {
        _polylines.removeWhere((polyline) =>
            polyline.polylineId.value == 'userToTransportistaRoute');
      });

      // Obtener las coordenadas de la nueva ruta
      List<LatLng> route = [];
      for (var step in data['routes'][0]['legs'][0]['steps']) {
        var polyline = step['polyline']['points'];
        route.addAll(_decodePolyline(polyline));
      }

      // Dibujar la polilínea verde en el mapa
      if (mounted) {
        setState(() {
          _polylines.add(Polyline(
            polylineId: PolylineId('userToTransportistaRoute'),
            color: Colors.green,
            width: 5,
            points: route,
          ));
        });
      }
    } else {
      print('Error al obtener la ruta: ${data['status']}');
    }
  }

// Función para decodificar la polilínea
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dLat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dLat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dLng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dLng;

      polyline.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return polyline;
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
          snippet: 'Patente: $vehiclePlate\n'
              'Tiempo estimado: $estimatedTime\n'
              'Distancia: $distance',
        ),
        onTap: () async {
          // Calculamos el tiempo estimado y la distancia cuando se toca el marcador
          Map<String, String> timeAndDistance =
              await _getEstimatedTimeAndDistance(
                  _userLocation, transportistaPosition);
          String estimatedTime = timeAndDistance['duration'] ?? 'Desconocido';
          String distance = timeAndDistance['distance'] ?? 'Desconocido';

          // Mostrar el BottomSheet con los detalles del transportista
          _showTransportistaDetails(
              name, lastname, vehiclePlate, estimatedTime, distance);

          // Actualizamos la InfoWindow con el tiempo estimado y la distancia
          setState(() {
            // Actualizamos la UI si es necesario
          });

          // Dibujar la ruta entre el usuario y el transportista (polilínea verde)
          _drawRoute(_userLocation, transportistaPosition);
          // Mostrar la ruta oficial
          _showOfficialRoute(transportistaId);
        },
      ));
    }

    setState(() {
      transportistaMarkers = markers;
    });
  }

  void _startListeningToLocationChanges() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Cada 10 metros
      ),
    ).listen((Position position) {
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });
      // Vuelve a dibujar la ruta con la nueva ubicación
      _updatePolylines();
    });
  }

  void _logout() async {
    try {
      // Obtén el ID del usuario actual
      String userId = FirebaseAuth.instance.currentUser!.uid;

      // Actualiza el atributo 'isLoggedIn' a false en Firestore
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isLoggedIn': false,
      });

      // Cierra la sesión del usuario
      await FirebaseAuth.instance.signOut();

      // Asegúrate de que el widget está montado antes de navegar
      if (mounted) {
        // Redirige al usuario a la página de login
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      // Muestra un mensaje de error si algo sale mal
      if (mounted) {
        // Verifica si el widget sigue montado antes de mostrar el error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cerrar sesión: ${e.toString()}')),
        );
      }
    }
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

      // se dibuja la polilínea para mostrar la ruta en el mapa
      setState(() {
        _polylines.add(Polyline(
          polylineId: PolylineId('officialRoute_$transportistaId'),
          color: const Color.fromARGB(255, 12, 13, 14),
          width: 5,
          points: route,
        ));
      });
    } else {
      // Si no hay ruta oficial
      print("No se encontró una ruta oficial para este transportista.");
    }
  }

  void _showTransportistaDetails(String name, String lastname,
      String vehiclePlate, String estimatedTime, String distance) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite controlar la altura
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          height:
              150, // Altura fija del BottomSheet, para que no cubra toda la pantalla
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Transportista: $name $lastname',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Patente: $vehiclePlate'),
              Text('Tiempo estimado: $estimatedTime'),
              Text('Distancia: $distance'),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    // Cancelar la suscripción cuando el widget se destruya
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Transportes Activos y Rutas Oficiales'),
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

                // Obtiene los transportistas
                var transportistas = snapshot.data!.docs;

                // Usamos addPostFrameCallback para actualizar los marcadores
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  // Actualiza los marcadores y polilíneas después de que se construya el widget
                  _buildMarkers(transportistas);
                });
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
                  onTap: (LatLng position) {},
                );
              },
            ),
    );
  }
}
