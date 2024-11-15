import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController; // Controlador del mapa
  LatLng _currentPosition = LatLng(0, 0); // Ubicación inicial en 0,0
  Set<Marker> _markers = {}; // Conjunto de marcadores

  @override
  void initState() {
    super.initState();
    _getCurrentLocation(); // Obtener ubicación al iniciar la app
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Verificar si el servicio de ubicación está habilitado
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("Los servicios de ubicación están deshabilitados.");
      return Future.error('Los servicios de ubicación están deshabilitados.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print("Los permisos de ubicación están denegados.");
        return Future.error('Los permisos de ubicación están denegados.');
      }
    }

    // Obtener la posición actual
    Position position = await Geolocator.getCurrentPosition();
    print("Ubicación obtenida: ${position.latitude}, ${position.longitude}");

    setState(() {
      _currentPosition = LatLng(
          position.latitude, position.longitude); // Actualizar la ubicación
      _markers.add(
        // Añadir marcador en la ubicación obtenida
        Marker(
          markerId: MarkerId('current_location'),
          position: _currentPosition,
        ),
      );
    });

    // Esperar un pequeño retraso para actualizar la cámara después de obtener la ubicación
    Future.delayed(Duration(milliseconds: 500), () {
      if (mapController != null) {
        // Asegurarse de que el controlador esté listo antes de actualizar la cámara
        print("Moviendo cámara a la ubicación obtenida");
        mapController!.animateCamera(CameraUpdate.newLatLng(_currentPosition));
        mapController!.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentPosition,
            zoom: 15, // Ajusta el zoom como necesites
          ),
        ));
      }
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mi Ubicación en Tiempo Real')),
      body: GoogleMap(
        onMapCreated:
            _onMapCreated, // Asignar el controlador cuando el mapa se haya creado
        initialCameraPosition: CameraPosition(
          target: _currentPosition, // ubicación inicial
          zoom: 15,
        ),
        markers: _markers, // Mostrar los marcadores
      ),
    );
  }
}
