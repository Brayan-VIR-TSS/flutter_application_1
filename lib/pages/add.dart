import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
//hola github

class AddUserPage extends StatefulWidget {
  @override
  _AddUserPageState createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _lastnameController = TextEditingController();
  final TextEditingController _rutController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  Future<void> _addUser() async {
    if (_formKey.currentState!.validate()) {
      await FirebaseFirestore.instance.collection('users').add({
        'name': _nameController.text,
        'lastname': _lastnameController.text,
        'rut': _rutController.text,
        'year': int.parse(
            _yearController.text), // Solo se llamará si pasa la validación
        'email': _emailController.text,
        'address': _addressController.text,
        'phone': _phoneController.text,
      });
      // Limpiar los campos después de agregar
      _nameController.clear();
      _lastnameController.clear();
      _rutController.clear();
      _yearController.clear();
      _emailController.clear();
      _addressController.clear();
      _phoneController.clear();

      // Mostrar un mensaje de éxito
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Usuario agregado')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Agregar Usuario'),
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
                  // Validar que solo contenga números
                  if (int.tryParse(value) == null) {
                    return 'Por favor ingresa un número válido';
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
                validator: (value) {
                  // Validar que solo contenga números
                  if (value != null &&
                      value.isNotEmpty &&
                      int.tryParse(value) == null) {
                    return 'Por favor ingresa un número de teléfono válido';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _addUser,
                child: Text('Registrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
