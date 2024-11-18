import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/logout_button.dart'; // cerrar cuenta

class RoutePage extends StatefulWidget {
  final String transportistaId;

  RoutePage({required this.transportistaId});

  @override
  _RoutePageState createState() => _RoutePageState();
}

class _RoutePageState extends State<RoutePage> {
  GoogleMapController? mapController;
  Set<Polyline> _polylines = Set(); // Para las rutas
  List<LatLng> _routeCoordinates = [];
  bool _isDataLoaded = false; // Para saber si los datos han sido cargados
  bool _hasError = false; // Para saber si hubo un error en la consulta

  @override
  void initState() {
    super.initState();
    _fetchRouteData(); // Traer los datos del recorrido
  }

  // Obtener el recorrido desde Firestore (ahora en la colección 'recorridos')
  Future<void> _fetchRouteData() async {
    try {
      FirebaseFirestore.instance
          .collection('recorridos')
          .where('transportistaId', isEqualTo: widget.transportistaId)
          .where('tripEnd',
              isNotEqualTo: null) // Solo los recorridos terminados
          .snapshots()
          .listen((snapshot) {
        _routeCoordinates
            .clear(); // Limpiar las coordenadas antes de añadir nuevas

        snapshot.docs.forEach((doc) {
          List<dynamic> locations = doc['locations'];
          _routeCoordinates.addAll(locations.map((loc) {
            return LatLng(loc['latitude'], loc['longitude']);
          }).toList());
        });

        setState(() {
          _addRoutePolyline(); // Actualizar la línea en el mapa
          _isDataLoaded = true; // Marcar los datos como cargados
        });
      });
    } catch (e) {
      print("Error al cargar los datos del recorrido: $e");
      setState(() {
        _hasError = true; // Si ocurre un error, marcar como error
        _isDataLoaded =
            true; // Para evitar que la pantalla quede en espera indefinida
      });
    }
  }

  // Añadir la ruta a la lista de Polylines
  void _addRoutePolyline() {
    if (_routeCoordinates.isNotEmpty) {
      _polylines.clear(); // Limpiar las polylines anteriores
      _polylines.add(Polyline(
        polylineId: PolylineId('route'),
        points: _routeCoordinates,
        color: Colors.blue, // Color de la ruta
        width: 5,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ruta del Transportista'),
        actions: [
          LogoutButton(), // Botón de cerrar sesión
        ],
      ),
      body: _hasError
          ? Center(child: Text("Hubo un error al cargar la ruta."))
          : _isDataLoaded
              ? GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _routeCoordinates.isNotEmpty
                        ? _routeCoordinates[0]
                        : LatLng(0, 0),
                    zoom: 14,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    mapController = controller;
                  },
                  polylines: _polylines,
                  markers: Set<
                      Marker>(), // Aquí puedes agregar los marcadores si es necesario
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                )
              : Center(child: CircularProgressIndicator()),
    );
  }
}
