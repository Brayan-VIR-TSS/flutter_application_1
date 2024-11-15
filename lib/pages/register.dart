import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add.dart'; // Importa tu archivo add.dart
import 'edit.dart'; // Importa tu archivo edit.dart
import 'geo.dart'; // Importa tu archivo geo.dart

class FirstPage extends StatefulWidget {
  @override
  _FirstPageState createState() => _FirstPageState();
}

class _FirstPageState extends State<FirstPage> {
  String searchTerm = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Usuarios'),
        actions: [
          IconButton(
            icon: Icon(Icons.home),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
          IconButton(
            icon: Icon(Icons.location_on),
            onPressed: () {
              // Navegar a la página de geo.dart
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        MapScreen()), // Asegúrate de que GeoPage sea el nombre correcto
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Buscar usuario(name)',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  searchTerm = value;
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final data = snapshot.data?.docs;

                // Filtra los usuarios según el término de búsqueda
                final filteredData = data?.where((doc) {
                  final name = doc['name'].toString().toLowerCase();
                  final lastname = doc['lastname'].toString().toLowerCase();
                  return name.contains(searchTerm.toLowerCase()) ||
                      lastname.contains(searchTerm.toLowerCase());
                }).toList();

                return ListView.builder(
                  itemCount: filteredData?.length ?? 0,
                  itemBuilder: (context, index) {
                    final doc = filteredData![index];
                    final dataMap =
                        doc.data() as Map<String, dynamic>?; // Conversión a Map

                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: ListTile(
                        title: Text('${doc['name']} ${doc['lastname']}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('RUT: ${doc['rut']}'),
                            Text('Edad: ${doc['year']}'),
                            Text('Email: ${doc['email']}'),
                            Text(
                                'Dirección: ${dataMap != null && dataMap.containsKey('address') ? dataMap['address'] : 'No disponible'}'),
                            Text(
                                'Teléfono: ${dataMap != null && dataMap.containsKey('phone') ? dataMap['phone'] : 'No disponible'}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        EditUserPage(userId: doc.id),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete),
                              onPressed: () async {
                                // Mostrar diálogo de confirmación
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: Text('Eliminar usuario'),
                                      content: Text(
                                          '¿Estás seguro de que deseas eliminar a ${doc['name']} ${doc['lastname']}?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(false),
                                          child: Text('Cancelar'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          child: Text('Eliminar'),
                                        ),
                                      ],
                                    );
                                  },
                                );

                                if (confirm == true) {
                                  // Elimina el documento de Firestore
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(doc.id)
                                      .delete();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddUserPage()),
          );
        },
        tooltip: 'Agregar Usuario',
        child: Icon(Icons.add),
      ),
    );
  }
}
