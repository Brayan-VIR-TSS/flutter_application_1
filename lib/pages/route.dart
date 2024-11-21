import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class RoutePage extends StatefulWidget {
  final String transportistaId;

  RoutePage({required this.transportistaId});

  @override
  _RoutePageState createState() => _RoutePageState();
}

class _RoutePageState extends State<RoutePage> {
  GoogleMapController? mapController;
  Set<Polyline> _polylines = Set(); // Para las rutas
  Set<Marker> _markers = Set(); // Para los marcadores
  List<LatLng> _currentRouteCoordinates = []; // Para el recorrido actual
  List<List<LatLng>> _allCompletedRoutes = []; // Lista de rutas completadas
  bool _isDataLoaded = false; // Para saber si los datos han sido cargados
  bool _hasError = false; // Para saber si hubo un error en la consulta

  @override
  void initState() {
    super.initState();
    _fetchRouteData(); // Traer los datos del recorrido
  }

  // Obtener el recorrido desde Firestore
  Future<void> _fetchRouteData() async {
    try {
      FirebaseFirestore.instance
          .collection('recorridos')
          .where('transportistaId', isEqualTo: widget.transportistaId)
          .orderBy('lastUpdated',
              descending: true) // Ordenar por la fecha de última actualización
          .limit(3) // Limitar a las tres últimas rutas
          .snapshots()
          .listen((snapshot) {
        // Limpiar las rutas anteriores antes de agregar las nuevas
        setState(() {
          _polylines.clear();
          _markers.clear();
          _currentRouteCoordinates.clear();
        });

        bool foundCurrentRoute = false;
        DateTime lastTripEnd = DateTime(2000); // Valor inicial para comparación

        snapshot.docs.forEach((doc) {
          bool isSharing = doc['isSharing'];
          List<dynamic> locations = doc['locations'];
          DateTime tripEnd = doc['tripEnd']?.toDate() ?? DateTime(2000);
          DateTime tripStart = doc['tripStart']?.toDate() ?? DateTime(2000);
          String tripId = doc.id; // ID del recorrido

          // Si el recorrido está en curso (isSharing: true)
          if (isSharing && !foundCurrentRoute) {
            setState(() {
              _currentRouteCoordinates.addAll(locations.map((loc) {
                return LatLng(loc['latitude'], loc['longitude']);
              }).toList());
            });
            foundCurrentRoute = true;
          } else if (!isSharing) {
            List<LatLng> completedRoute = locations.map((loc) {
              return LatLng(loc['latitude'], loc['longitude']);
            }).toList();

            // Guardar todas las rutas completadas
            setState(() {
              _allCompletedRoutes.add(completedRoute);
            });

            // Limitar a solo las tres últimas rutas completadas
            if (_allCompletedRoutes.length > 3) {
              _allCompletedRoutes.removeAt(0); // Eliminar la ruta más antigua
            }

            // Agregar marcadores de inicio y fin
            _addStartMarker(
                locations[0], tripStart, tripId); // Marcador de inicio
            _addEndMarker(locations.last, tripEnd, tripId); // Marcador de fin
          }
        });

        //agrega las rutas al mapa
        setState(() {
          // Añadir las rutas completadas al mapa
          for (var route in _allCompletedRoutes) {
            _addRoutePolyline(route,
                const Color.fromARGB(255, 223, 250, 19)); // Ruta completada
          }

          // Añadir la ruta actual al mapa
          if (_currentRouteCoordinates.isNotEmpty) {
            _addRoutePolyline(_currentRouteCoordinates,
                const Color.fromARGB(255, 2, 185, 231)); // Ruta actual
          }

          _isDataLoaded = true;
        });
      });
    } catch (e) {
      print("Error al cargar los datos del recorrido: $e");
      setState(() {
        _hasError = true;
        _isDataLoaded = true;
      });
    }
  }

  // Añadir la ruta a la lista de Polylines con un color específico
  void _addRoutePolyline(List<LatLng> route, Color color) {
    if (route.isNotEmpty) {
      _polylines.add(Polyline(
        polylineId: PolylineId(color == const Color.fromARGB(255, 2, 185, 231)
            ? 'current_route'
            : 'completed_route'),
        points: route,
        color: color, // Usar el color pasado como parámetro
        width: 5,
      ));
    }
  }

  // Función para agregar un marcador de inicio con las fechas
  void _addStartMarker(
      Map<String, dynamic> firstLocation, DateTime tripStart, String tripId) {
    String formattedStartDate = DateFormat('yyyy-MM-dd').format(tripStart);
    String formattedStartTime = DateFormat('/ HH:mm').format(tripStart);

    final startMarker = Marker(
      markerId: MarkerId('${tripId}tripStart'), // Usar el ID del recorrido
      position: LatLng(firstLocation['latitude'], firstLocation['longitude']),
      infoWindow: InfoWindow(
        title: 'ID Recorrido: $tripId',
        snippet: 'Inicio: $formattedStartDate $formattedStartTime',
      ),
    );
    setState(() {
      _markers.add(startMarker);
    });
  }

  // Función para agregar un marcador de fin con las fechas
  void _addEndMarker(
      Map<String, dynamic> lastLocation, DateTime tripEnd, String tripId) {
    String formattedEndDate = DateFormat('yyyy-MM-dd').format(tripEnd);
    String formattedEndTime = DateFormat('/ HH:mm').format(tripEnd);

    final endMarker = Marker(
      markerId: MarkerId('${tripId}tripEnd'), // Usar el ID del recorrido
      position: LatLng(lastLocation['latitude'], lastLocation['longitude']),
      infoWindow: InfoWindow(
        title: 'ID Recorrido: $tripId',
        snippet: 'Fin: $formattedEndDate $formattedEndTime',
      ),
    );
    setState(() {
      _markers.add(endMarker);
    });
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
                    target: _polylines.isNotEmpty
                        ? _polylines.first.points[0]
                        : LatLng(0, 0),
                    zoom: 14,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    mapController = controller;
                  },
                  polylines: _polylines,
                  markers: _markers, // Mostrar los marcadores con las fechas
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                )
              : Center(child: CircularProgressIndicator()),
    );
  }
}
