import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class LocationAlertDialog extends StatelessWidget {
  final String title;
  final String content;
  final Function onAllow;
  final Function onDeny;

  LocationAlertDialog({
    required this.title,
    required this.content,
    required this.onAllow,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text(
        title,
        style: TextStyle(
          color: Colors.blueAccent,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            content,
            style: TextStyle(
              fontSize: 16,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              onAllow();
              Navigator.of(context).pop();
            },
            child: Text(
              'Permitir Ubicación',
              style: TextStyle(fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 30),
            ),
          ),
          TextButton(
            onPressed: () {
              onDeny();
              Navigator.of(context).pop();
            },
            child: Text(
              'No Permitir',
              style: TextStyle(fontSize: 16, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController nameController = TextEditingController();
  TextEditingController lastnameController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  TextEditingController rutController = TextEditingController();
  TextEditingController yearController = TextEditingController();
  TextEditingController vehicleModelController = TextEditingController();
  TextEditingController vehiclePlateController = TextEditingController();
  TextEditingController vehicleTypeController = TextEditingController();

  String role = 'pasajero';
  bool isTransportista = false;

  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return LocationAlertDialog(
            title: 'Ubicación Requerida',
            content:
                'Para que esta aplicación funcione correctamente, necesitamos acceso a tu ubicación. ¿Puedes habilitarla?',
            onAllow: () async {
              await Geolocator.openLocationSettings();
            },
            onDeny: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('No se puede continuar sin la ubicación')),
              );
            },
          );
        },
      );
      return;
    }
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return LocationAlertDialog(
            title: 'Permiso de Ubicación Denegado',
            content:
                'Para que esta aplicación funcione correctamente, necesitamos acceso a tu ubicación. ¿Puedes permitirlo?',
            onAllow: () async {
              await Geolocator.openLocationSettings();
            },
            onDeny: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'No se puede continuar sin el permiso de ubicación')),
              );
            },
          );
        },
      );
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentPosition = position;
    });
  }

  // Función para registrar el usuario
  Future<void> _registerUser() async {
    if (_formKey.currentState!.validate() && _currentPosition != null) {
      try {
        UserCredential userCredential =
            await _auth.createUserWithEmailAndPassword(
          email: emailController.text,
          password: passwordController.text,
        );

        // Eliminar espacios en el teléfono antes de almacenarlo
        String phoneWithoutSpaces = phoneController.text.replaceAll(' ', '');

        // Crear el mapa de datos del usuario
        Map<String, dynamic> userData = {
          'email': emailController.text,
          'name': nameController.text,
          'lastname': lastnameController.text,
          'phone': phoneWithoutSpaces, // Almacenamos como string sin espacios
          'year': int.parse(yearController.text),
          'rut': rutController.text,
          'role': role,
          'geo':
              GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
        };

        if (role == 'transportista') {
          userData.addAll({
            'vehicle_model': vehicleModelController.text,
            'vehicle_plate': vehiclePlateController.text,
            'vehicle_type': vehicleTypeController.text,
          });
        }

        // Registramos en Firestore dependiendo del rol
        if (role == 'transportista') {
          await _firestore
              .collection('clients')
              .doc(userCredential.user!.uid)
              .set(userData);
        } else {
          await _firestore
              .collection('users')
              .doc(userCredential.user!.uid)
              .set(userData);
        }

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Usuario registrado exitosamente')));
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Registro de Usuario')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            // Email
            children: [
              TextFormField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'Ejemplo: correo@example.com',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa un correo electrónico';
                  }
                  // Expresión regular para validar los dominios permitidos
                  String pattern =
                      r'^[a-zA-Z0-9._%+-]+@(gmail\.com|gmail\.cl|hotmail\.com|hotmail\.cl|example\.com|outlook\.com)$';
                  RegExp regExp = RegExp(pattern);

                  if (!regExp.hasMatch(value)) {
                    return 'Por favor ingresa un correo electrónico válido (gmail, hotmail, example, etc.)';
                  }
                  return null;
                },
              ),
              // Contraseña
              TextFormField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  hintText: 'Password',
                ),
                obscureText: true, // Para ocultar la contraseña
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa una contraseña';
                  }

                  // Expresión regular para validar los requisitos de la contraseña
                  // - Al menos 9 caracteres
                  // - Al menos una letra mayúscula
                  // - Al menos un número
                  // - Al menos un símbolo especial
                  String pattern =
                      r'^(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*(),.?":{}|<>]).{9,}$';

                  RegExp regExp = RegExp(pattern);

                  // Si la contraseña no cumple con el patrón, mostramos un mensaje de error
                  if (!regExp.hasMatch(value)) {
                    return 'La contraseña debe tener al menos 9 caracteres, una mayúscula, un número y un símbolo';
                  }

                  return null;
                },
              ),
              // Nombre
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Name',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp('[a-zA-ZáéíóúÁÉÍÓÚÑñ ]')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa tu nombre';
                  }
                  return null;
                },
              ),
              // Apellido
              TextFormField(
                controller: lastnameController,
                decoration: InputDecoration(
                  labelText: 'Apellido',
                  hintText: 'Last Name',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp('[a-zA-ZáéíóúÁÉÍÓÚÑñ ]')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa tu apellido';
                  }
                  return null;
                },
              ),
              // Teléfono
              TextFormField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: 'Teléfono',
                  hintText: 'Ejemplo: 9 9999 9999',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter
                      .digitsOnly, // Solo permite números
                  LengthLimitingTextInputFormatter(9), // Limita a 9 dígitos
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    String text = newValue.text;

                    // Formateamos el texto para que tenga el formato 9 9999 9999
                    if (text.length == 2) {
                      text = '${text.substring(0, 1)} ${text.substring(1)}';
                    } else if (text.length == 6) {
                      // Aseguramos que el substring sea válido
                      if (text.length >= 5) {
                        text =
                            '${text.substring(0, 1)} ${text.substring(1, 5)} ${text.substring(5)}';
                      }
                    } else if (text.length > 6) {
                      // Aseguramos que el substring sea válido
                      if (text.length >= 5) {
                        text =
                            '${text.substring(0, 1)} ${text.substring(1, 5)} ${text.substring(5, 9)}';
                      }
                    }

                    // Aseguramos de que el cursor esté al final del texto
                    int cursorPosition = text.length;

                    return TextEditingValue(
                      text: text,
                      selection:
                          TextSelection.collapsed(offset: cursorPosition),
                    );
                  }),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa un teléfono';
                  }

                  // Eliminar los espacios antes de validar
                  String phoneWithoutSpaces = value.replaceAll(' ', '');

                  // Validar que sea un número válido y que tenga 9 dígitos
                  if (int.tryParse(phoneWithoutSpaces) == null) {
                    return 'Por favor ingresa un número válido';
                  }
                  if (phoneWithoutSpaces.length != 9) {
                    return 'El teléfono debe tener 9 dígitos';
                  }
                  return null;
                },
              ),

              // RUT
              TextFormField(
                controller: rutController,
                decoration: InputDecoration(
                  labelText: 'RUT',
                  hintText: 'Ejemplo: 11.111.111-k',
                ),

                //aqui las restriccionse
                inputFormatters: [
                  LengthLimitingTextInputFormatter(
                      12), // Limita la longitud máxima de caracteres
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    String text = newValue.text;
                    text = text.replaceAll(RegExp(r'[^0-9kK]'), '');
                    // Formatear con puntos
                    if (text.length > 1) {
                      text = text.replaceRange(text.length - 1, text.length,
                          '-${text[text.length - 1]}');
                    }
                    if (text.length > 4) {
                      text = text.replaceRange(text.length - 5, text.length - 4,
                          '.${text[text.length - 5]}');
                    }
                    if (text.length > 8) {
                      text = text.replaceRange(text.length - 9, text.length - 8,
                          '.${text[text.length - 9]}');
                    }
                    if (text.length > 12) {
                      text = text.replaceRange(text.length - 13,
                          text.length - 12, '.${text[text.length - 13]}');
                    }
                    return TextEditingValue(
                      text: text,
                      selection: TextSelection.collapsed(offset: text.length),
                    );
                  }),
                ],

                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa tu RUT';
                  }
                  // Expresión regular para validar el formato: x.xxx.xxx-x o xx.xxx.xxx-x, con la letra K o k como dígito verificador
                  if (!RegExp(r'^\d{1,2}\.\d{3}\.\d{3}-[\dKk]$')
                      .hasMatch(value)) {
                    return 'RUT no válido';
                  }
                  return null;
                },
              ),
              //Edad
              TextFormField(
                controller: yearController,
                decoration: InputDecoration(labelText: 'Edad'),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter
                      .digitsOnly, // Solo permite números
                  LengthLimitingTextInputFormatter(2), // Limita a 2 dígitos
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa su Edad';
                  }
                  // Validación para asegurarse de que la edad es un número válido
                  int? age = int.tryParse(value);
                  if (age == null) {
                    return 'Por favor ingresa un número válido';
                  }
                  // Validar que la edad no sea 00
                  if (age == 0) {
                    return 'La edad no puede ser 0';
                  }
                  // Validar que la edad esté dentro de un rango razonable (0 a 120 años)
                  if (age < 0 || age > 120) {
                    return 'Por favor ingresa una edad válida entre 0 y 120 años';
                  }
                  return null;
                },
              ),
              Row(children: [
                Text('Rol: '),
                DropdownButton<String>(
                  value: role,
                  items:
                      <String>['pasajero', 'transportista'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      role = newValue!;
                      isTransportista = role == 'transportista';
                    });
                  },
                ),
              ]),

              // Solo mostrar campos adicionales si el rol es 'transportista'
              // Modelo
              if (isTransportista) ...[
                TextFormField(
                  controller: vehicleModelController,
                  decoration: InputDecoration(labelText: 'Modelo del vehículo'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa el modelo del vehículo';
                    }
                    return null;
                  },
                ),
                // Placa
                TextFormField(
                  controller: vehiclePlateController,
                  decoration: InputDecoration(
                    labelText: 'Placa del vehículo',
                    hintText: 'Ejemplo: XX XX XX', // Ejemplo de formato
                  ),
                  inputFormatters: [
                    UpperCaseTextFormatter(), // Usamos el formateador que acabamos de crear
                    LengthLimitingTextInputFormatter(
                        8), // Limita la longitud a 6 caracteres
                    VehiclePlateInputFormatter(), // Formato personalizado para agregar guiones
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa la placa del vehículo';
                    }

                    // Validar que la placa tenga el formato correcto (puedes añadir otras validaciones si lo necesitas)
                    String plateWithoutSpaces = value.replaceAll(
                        ' ', ''); // Eliminamos los espacios para validar
                    if (plateWithoutSpaces.length != 8) {
                      // Limitar a 6 caracteres
                      return 'La placa debe tener 6 caracteres';
                    }

                    return null;
                  },
                ),
                //Tipo
                TextFormField(
                  controller: vehicleTypeController,
                  decoration: InputDecoration(
                    labelText: 'Tipo de vehículo',
                    hintText: 'Micro/Moto/Camion/etc',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa el tipo de vehículo';
                    }
                    return null;
                  },
                ),
              ],

              // Botón de solicitar ubicación
              ElevatedButton(
                onPressed: () async {
                  await _determinePosition(); // Llamamos a la función para solicitar ubicación
                  if (_currentPosition != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Ubicación obtenida: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}'),
                      ),
                    );
                  }
                },
                child: Text('Obtener Ubicación'),
              ),
              SizedBox(height: 20),

              // Botón para registrar el usuario
              ElevatedButton(
                onPressed: _registerUser,
                child: Text('Registrar'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Formato para convertir el texto de la patente a mayúsculas
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

// Formateador para agregar guiones cada 2 caracteres
class VehiclePlateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Eliminar los guiones temporales y los espacios
    String newText = newValue.text.replaceAll('-', '').replaceAll(' ', '');

    // Limitar a 6 caracteres
    if (newText.length > 6) {
      newText = newText.substring(0, 6);
    }

    // Insertar los guiones cada 2 caracteres
    String formattedText = _insertHyphens(newText);

    // Asegurar que el cursor esté al final del texto
    int cursorPosition = formattedText.length;

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );
  }

  // Función que inserta guiones cada 2 caracteres
  String _insertHyphens(String text) {
    StringBuffer result = StringBuffer();
    int count = 0;

    // Recorremos el texto y agregamos un guion después de cada dos caracteres
    for (int i = 0; i < text.length; i++) {
      result.write(text[i]);
      count++;
      if (count == 2 && i != text.length - 1) {
        result.write('-');
        count = 0;
      }
    }

    return result.toString();
  }
}
