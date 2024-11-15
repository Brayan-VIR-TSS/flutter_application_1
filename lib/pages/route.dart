import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      // Realizamos la consulta a Firestore para obtener los recorridos del transportista
      FirebaseFirestore.instance
          .collection(
              'recorridos') // Ahora estamos obteniendo los datos de 'recorridos'
          .where('transportistaId',
              isEqualTo:
                  widget.transportistaId) // Filtramos por el transportista
          .get()
          .then((snapshot) {
        snapshot.docs.forEach((doc) {
          // Obtenemos el historial de ubicaciones desde Firestore
          List<dynamic> locations = doc['locations']; // Lista de ubicaciones
          _routeCoordinates = locations.map((loc) {
            return LatLng(loc['latitude'], loc['longitude']);
          }).toList();

          setState(() {
            _addRoutePolyline(); // Trazar la línea en el mapa
            _isDataLoaded = true; // Indicamos que los datos fueron cargados
          });
        });
      });
    } catch (e) {
      print("Error al cargar los datos del recorrido: $e");
      setState(() {
        _hasError = true; // Si ocurre un error, marcamos el error
      });
    }
  }

  // Añadir la ruta a la lista de Polylines
  void _addRoutePolyline() {
    if (_routeCoordinates.isNotEmpty) {
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
                  polylines: _polylines, // Mostrar la ruta en el mapa
                  markers: Set<Marker>(), // Puedes agregar marcadores si deseas
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                )
              : Center(
                  child:
                      CircularProgressIndicator()), // Cargar mientras no haya datos
    );
  }
}
