import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math';

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
  List<Map<String, dynamic>> _allCompletedRoutesWithIds =
      []; // Lista de rutas completadas con ID
  bool _isDataLoaded = false; // Para saber si los datos han sido cargados
  bool _hasError = false; // Para saber si hubo un error en la consulta
  bool _isOfficialRouteSelected =
      false; // Para saber si se seleccionó una ruta oficial
  List<LatLng> _selectedOfficialRoute = []; // Ruta oficial seleccionada

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
          .listen((snapshot) async {
        // Limpiar las rutas anteriores antes de agregar las nuevas
        setState(() {
          _polylines.clear();
          _markers.clear();
          _currentRouteCoordinates.clear();
          _allCompletedRoutesWithIds
              .clear(); // Limpiar la lista de rutas con ID
        });

        bool foundCurrentRoute = false;

        for (var doc in snapshot.docs) {
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

            // Guardar todas las rutas completadas con su ID
            setState(() {
              _allCompletedRoutesWithIds.add({
                'tripId':
                    tripId, // Guardamos el ID de la ruta junto con las coordenadas
                'route': completedRoute,
                'isOfficial': false, //inicialmente como no oficial
              });

              // Limitar a solo las tres últimas rutas completadas??es redundante??
              if (_allCompletedRoutesWithIds.length > 3) {
                _allCompletedRoutesWithIds
                    .removeAt(0); // Eliminar la ruta más antigua
              }

              // Agregar marcadores de inicio y fin
              _addStartMarker(
                  locations[0], tripStart, tripId); // Marcador de inicio
              _addEndMarker(locations.last, tripEnd, tripId); // Marcador de fin
            });
          }
        }

        // Ahora que tenemos todas las rutas, incluimos las oficiales
        for (var route in _allCompletedRoutesWithIds) {
          // Recuperar la información de si la ruta es oficial
          bool isOfficialRoute = await _checkIfRouteIsOfficial(route['tripId']);
          route['isOfficial'] = isOfficialRoute;

          // Añadir la ruta con el color correspondiente
          _addRoutePolyline(
            route['route'],
            isOfficialRoute
                ? Colors.black
                : const Color.fromARGB(255, 223, 250, 19),
            isOfficialRoute: isOfficialRoute,
          );
        }

        if (_currentRouteCoordinates.isNotEmpty) {
          _addRoutePolyline(
            _currentRouteCoordinates,
            const Color.fromARGB(255, 2, 185, 231),
          ); // Ruta actual
        }

        setState(() {
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

  // Función para manejar la selección de una ruta oficial
  Future<void> _showOfficialRoute() async {
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('official_route')
          .where('transportistaId', isEqualTo: widget.transportistaId)
          .get();

      if (snapshot.docs.isNotEmpty) {
        var route = snapshot
            .docs.first; // Tomamos la primera ruta oficial del transportista
        List<dynamic> locations = route['locations'];

        setState(() {
          _isOfficialRouteSelected = true;
          _selectedOfficialRoute = locations
              .map((loc) => LatLng(loc['latitude'], loc['longitude']))
              .toList();
        });

        // Limpiar las rutas anteriores
        _polylines.clear();
        _markers.clear();

        // Agregar la ruta oficial
        _addRoutePolyline(
          _selectedOfficialRoute,
          Colors.black, // Color de la ruta oficial
          isOfficialRoute: true,
        );

        // Agregar marcadores de inicio y fin
        _addStartMarker(locations[0], DateTime.now(), 'officialStart');
        _addEndMarker(locations.last, DateTime.now(), 'officialEnd');

        // Centrar el mapa en la ruta oficial
        _centerMapOnRoute(_selectedOfficialRoute);
      }
    } catch (e) {
      print("Error al cargar la ruta oficial: $e");
    }
  }

  // Función para centrar el mapa en la ruta seleccionada
  void _centerMapOnRoute(List<LatLng> route) {
    if (route.isNotEmpty) {
      LatLngBounds bounds = _calculateBounds(route);
      mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    }
  }

  // Calcular los límites de la ruta (para hacer zoom adecuado)
  LatLngBounds _calculateBounds(List<LatLng> route) {
    double minLat = route[0].latitude;
    double maxLat = route[0].latitude;
    double minLng = route[0].longitude;
    double maxLng = route[0].longitude;

    for (LatLng point in route) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  Future<bool> _checkIfRouteIsOfficial(String tripId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('official_route')
          .where('tripId', isEqualTo: tripId)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print("Error al verificar si la ruta es oficial: $e");
      return false;
    }
  }

// Añadir la ruta a la lista de Polylines con un color específico
  void _addRoutePolyline(List<LatLng> route, Color color,
      {bool isOfficialRoute = false}) {
    if (route.isNotEmpty) {
      _polylines.add(Polyline(
        polylineId: PolylineId(color == const Color.fromARGB(255, 2, 185, 231)
            ? 'current_route'
            : isOfficialRoute
                ? 'official_route'
                : 'completed_route'),
        points: route,
        color:
            isOfficialRoute ? Colors.black : color, // Si es oficial, usar negro
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

  // Botón para recargar el mapa
  void _reloadMap() {
    setState(() {
      _polylines.clear(); // Limpiar las rutas actuales
      _markers.clear(); // Limpiar los marcadores
      _fetchRouteData(); // Recargar los datos de las rutas
    });
  }

// Mostrar un BottomSheet para seleccionar la ruta
  void _showRouteSelectionMenu(List<Map<String, dynamic>> routes) {
    showModalBottomSheet(
      context: context,
      isScrollControlled:
          true, // Asegura que el BottomSheet no ocupe toda la pantalla
      builder: (context) {
        return Container(
          height: 250, // Ajusta la altura según lo necesario
          child: ListView.builder(
            itemCount: routes.length,
            itemBuilder: (context, index) {
              String tripId = routes[index]['tripId'];
              bool isRouteSaved = false;

              // Verifica si la ruta ya está guardada
              FirebaseFirestore.instance
                  .collection('official_route')
                  .where('tripId', isEqualTo: tripId)
                  .get()
                  .then((querySnapshot) {
                isRouteSaved = querySnapshot.docs.isNotEmpty;
                setState(() {}); // Redibujar para reflejar el estado
              });

              return ListTile(
                title: Text("ID de la ruta: $tripId"),
                trailing: isRouteSaved
                    ? Icon(Icons.star,
                        color: Colors.yellow) // Ícono de ruta guardada
                    : null,
                onTap: () {
                  if (isRouteSaved) {
                    // Si la ruta ya está guardada, preguntamos si desea borrarla
                    _showDeleteConfirmationDialog(tripId);
                  } else {
                    // Si la ruta no está guardada, guardarla
                    _saveRoute(routes[index]['route'], routes[index]['tripId']);
                    Navigator.pop(context); // Cerrar el bottom sheet
                  }
                },
              );
            },
          ),
        );
      },
    );
  }

// Función para mostrar el diálogo de confirmación antes de borrar la ruta
  void _showDeleteConfirmationDialog(String tripId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Eliminar Ruta"),
          content: Text(
              "Esta ruta está guardada. ¿Desea borrarla de los recorridos oficiales?"),
          actions: <Widget>[
            TextButton(
              child: Text("Cancelar"),
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar el diálogo sin hacer nada
              },
            ),
            TextButton(
              child: Text("Eliminar"),
              onPressed: () {
                // Eliminar la ruta de Firestore
                _deleteRouteFromOfficial(tripId);
                Navigator.of(context).pop(); // Cerrar el diálogo
              },
            ),
          ],
        );
      },
    );
  }

// Función para eliminar la ruta de Firestore
  Future<void> _deleteRouteFromOfficial(String tripId) async {
    try {
      // Buscar el documento que contiene la ruta en la colección 'official_route'
      var snapshot = await FirebaseFirestore.instance
          .collection('official_route')
          .where('tripId', isEqualTo: tripId)
          .get();

      // Eliminar el documento
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      // Actualizar la lista de rutas guardadas
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Ruta eliminada de los Recorridos ficiales.")),
      );

      Navigator.pop(context); // Esto cierra el BottomSheet

      _fetchRouteData(); // Recargar las rutas
      // No eliminamos la ruta de la lista que usamos para mostrar en el menú.
      // Solo eliminamos de la base de datos.
    } catch (e) {
      print("Error al eliminar la ruta: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hubo un error al eliminar la ruta")),
      );
    }
  }

  // Función para verificar si la ruta ya "está" guardada
  Future<bool> _isRouteAlreadySaved(String tripId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('official_route')
          .where('tripId',
              isEqualTo: tripId) // Verificar si el tripId ya está guardado
          .limit(1)
          .get();

      return snapshot
          .docs.isNotEmpty; // Si ya existe algún documento con ese tripId
    } catch (e) {
      print("Error al verificar si la ruta está guardada: $e");
      return false;
    }
  }

  // Verificar si el transportista ya tiene "una" ruta guardada
  Future<bool> _hasOfficialRoute() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('official_route')
          .where('transportistaId', isEqualTo: widget.transportistaId)
          .limit(1) // Solo buscamos uno
          .get();

      return snapshot
          .docs.isNotEmpty; // Si ya existe un documento con el transportista
    } catch (e) {
      print("Error al verificar recorrido oficial: $e");
      return false;
    }
  }

  Future<void> _saveRoute(List<LatLng> route, String tripId) async {
    // Verificar si el transportista ya tiene un recorrido oficial guardado
    bool hasOfficialRoute = await _hasOfficialRoute();

    if (hasOfficialRoute) {
      // Mostrar un mensaje de confirmación para borrar el recorrido oficial anterior
      _showDeleteConfirmationDialogBeforeSaving(route, tripId);
    } else {
      // Si no hay recorrido oficial, guardamos este recorrido como oficial
      _saveAsOfficial(route, tripId);
    }
  }

// Función para guardar la ruta como oficial
  Future<void> _saveAsOfficial(List<LatLng> route, String tripId) async {
    // Convertir la lista de LatLng a una lista de mapas para almacenar en Firestore
    List<Map<String, dynamic>> locations = route.map((latLng) {
      return {'latitude': latLng.latitude, 'longitude': latLng.longitude};
    }).toList();

    try {
      // Guardar la ruta en Firestore en la colección 'official_route'
      await FirebaseFirestore.instance.collection('official_route').add({
        'tripId': tripId, // Guardamos también el ID de la ruta
        'transportistaId': widget.transportistaId,
        'locations': locations,
        'savedAt': FieldValue.serverTimestamp(),
        'isOfficial': true, // Campo que marca la ruta como oficial
      });

      // Confirmar al usuario que la ruta fue guardada
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Ruta guardada como oficial")),
      );

      _fetchRouteData(); // Recargar las rutas
    } catch (e) {
      print("Error al guardar la ruta: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hubo un error al guardar la ruta")),
      );
    }
  }

  // Función para mostrar el diálogo de confirmación antes de borrar el recorrido anterior
  void _showDeleteConfirmationDialogBeforeSaving(
      List<LatLng> newRoute, String newTripId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Borrar Recorrido Oficial"),
          content: Text(
              "Solo se le permite guardar un recorrido oficial. ¿Desea borrar el anterior recorrido oficial y guardar este nuevo?"),
          actions: <Widget>[
            TextButton(
              child: Text("Cancelar"),
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar el diálogo sin hacer nada
              },
            ),
            TextButton(
              child: Text("Eliminar y Guardar"),
              onPressed: () {
                // Eliminar el recorrido oficial anterior
                _deletePreviousOfficialRoute().then((_) {
                  // Luego de borrar, guardar el nuevo recorrido
                  _saveAsOfficial(newRoute, newTripId);
                  Navigator.of(context).pop(); // Cerrar el diálogo
                });
              },
            ),
          ],
        );
      },
    );
  }

  // Función para eliminar el recorrido oficial anterior
  Future<void> _deletePreviousOfficialRoute() async {
    try {
      // Buscar el documento que contiene el recorrido oficial del transportista
      var snapshot = await FirebaseFirestore.instance
          .collection('official_route')
          .where('transportistaId', isEqualTo: widget.transportistaId)
          .get();

      // Eliminar el documento
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      // Confirmación de eliminación
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Recorrido oficial anterior eliminado.")),
      );
    } catch (e) {
      print("Error al eliminar el recorrido oficial anterior: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                "Hubo un error al eliminar el recorrido oficial anterior.")),
      );
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
      // Agregar BottomAppBar con ambos botones
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment
                .spaceAround, // Esto coloca los botones con espacio entre ellos
            children: [
              ElevatedButton(
                onPressed:
                    _showOfficialRoute, // Función que muestra la ruta oficial
                child: Text("Mostrar Ruta Oficial"),
              ),
              ElevatedButton(
                onPressed: () => _showRouteSelectionMenu(
                    _allCompletedRoutesWithIds), // Función que muestra el menú para seleccionar ruta
                child: Text("Seleccionar Ruta Official"),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _reloadMap,
        child: Icon(Icons.refresh), // Ícono de recarga
        tooltip:
            'Recargar mapa', // Texto que aparece cuando se mantiene presionado
      ),
    );
  }
}
