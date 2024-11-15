import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditUserPage extends StatefulWidget {
  final String userId; // ID del usuario a editar

  EditUserPage({required this.userId});

  @override
  _EditUserPageState createState() => _EditUserPageState();
}

class _EditUserPageState extends State<EditUserPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _lastnameController = TextEditingController();
  final TextEditingController _rutController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      // Asegúrate de que el documento existe
      if (doc.exists) {
        // Usa 'data()' para obtener los datos
        final data = doc.data() as Map<String, dynamic>;
        _nameController.text = data['name'] ?? '';
        _lastnameController.text = data['lastname'] ?? '';
        _rutController.text = data['rut'] ?? '';
        _yearController.text = data['year']?.toString() ?? '';
        _emailController.text = data['email'] ?? '';
        _addressController.text = data['address'] ?? '';
        _phoneController.text = data['phone']?.toString() ?? '';
      } else {
        // Manejar el caso en que el documento no existe
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Usuario no encontrado')),
        );
        Navigator.pop(context); // Regresar a la pantalla anterior
      }
    } catch (e) {
      // Manejar errores de carga
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar datos: $e')),
      );
    }
  }

  Future<void> _updateUser() async {
    if (_formKey.currentState!.validate()) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
        'name': _nameController.text,
        'lastname': _lastnameController.text,
        'rut': _rutController.text,
        'year': int.parse(_yearController.text),
        'email': _emailController.text,
        'address': _addressController.text,
        'phone': _phoneController.text,
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Usuario actualizado')));
      Navigator.pop(context); // Regresar a la pantalla anterior
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Editar Usuario'),
        actions: [
          IconButton(
            icon: Icon(Icons.home),
            onPressed: () {
              // Navegar a la primera pantalla (main.dart)
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Nombre'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa un nombre';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _lastnameController,
                decoration: InputDecoration(labelText: 'Apellido'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa un apellido';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _rutController,
                decoration: InputDecoration(labelText: 'RUT'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa un RUT';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _yearController,
                decoration: InputDecoration(labelText: 'Edad'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa un año';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (value == null || value.isEmpty || !value.contains('@')) {
                    return 'Por favor ingresa un email válido';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(labelText: 'Dirección'),
              ),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: 'Teléfono'),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _updateUser,
                child: Text('Actualizar Usuario'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
