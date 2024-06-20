import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:mapas_api/blocs/location/location_bloc.dart';
import 'package:mapas_api/screens/home_pasajero.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';

class GenerarAsistenciaScreen extends StatefulWidget {
  final int programacionAcademicaId;

  const GenerarAsistenciaScreen(
      {super.key, required this.programacionAcademicaId});

  @override
  _GenerarAsistenciaScreenState createState() =>
      _GenerarAsistenciaScreenState();
}

class _GenerarAsistenciaScreenState extends State<GenerarAsistenciaScreen> {
  late LocationBloc locationBloc;
  TextEditingController observacionesController = TextEditingController();
  TextEditingController latitudController = TextEditingController();
  TextEditingController longitudController = TextEditingController();
  TextEditingController fechaController = TextEditingController();
  bool isLoading = true;
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    final isAuthenticated = await auth.authenticate(
      localizedReason: 'Por favor autentíquese para generar asistencia',
      options: const AuthenticationOptions(biometricOnly: true),
    );

    if (isAuthenticated) {
      locationBloc = BlocProvider.of<LocationBloc>(context);
      locationBloc.startFollowingUser();
      locationBloc.stream.listen((state) {
        if (state.lastKnownLocation != null && isLoading) {
          latitudController.text = state.lastKnownLocation!.latitude.toString();
          longitudController.text =
              state.lastKnownLocation!.longitude.toString();
          setState(() {
            isLoading = false;
          });
        }
      });

      final DateTime now = DateTime.now();
      final String formattedFecha =
          DateFormat('yyyy-MM-dd – kk:mm').format(now);
      fechaController.text = formattedFecha;
    } else {
      // If authentication fails, go back to the previous screen
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    locationBloc.stopFollowingUser();
    observacionesController.dispose();
    latitudController.dispose();
    longitudController.dispose();
    fechaController.dispose();
    super.dispose();
  }

  Future<void> _enviarAsistencia() async {
    final prefs = await SharedPreferences.getInstance();
    final docenteId = prefs.getInt('userId');
    if (docenteId == null) {
      // Manejar el caso en que el docenteId no esté disponible
      return;
    }

    final DateTime now = DateTime.now(); // Aumentar la hora en 2 horas
    final String fecha = now.toIso8601String();
    print(fecha);
    print(widget.programacionAcademicaId);
    final response = await http.post(
      Uri.parse('http://165.227.100.249/asistencias/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'programacionAcademicaId': widget.programacionAcademicaId,
        'estadoAsistenciaId': 1,
        'docenteId': docenteId,
        'fecha': fecha,
        'observaciones': observacionesController.text,
        'fotoUrl': '',
        'latitud': double.parse(latitudController.text),
        'longitud': double.parse(longitudController.text),
      }),
    );

    if (response.statusCode == 200) {
      // Asistencia enviada exitosamente
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Asistencia enviada exitosamente',
          ),
          backgroundColor: Colors.green,
        ),
      );
      await Future.delayed(const Duration(seconds: 2));
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MapScreen()),
        (Route<dynamic> route) => false,
      );
    } else {
      // Manejar error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al enviar la asistencia'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generar Asistencia'),
        backgroundColor: const Color.fromARGB(255, 4, 91, 108),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: fechaController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Fecha',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: observacionesController,
                    decoration: const InputDecoration(
                      labelText: 'Observaciones',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: latitudController,
                    readOnly: false,
                    decoration: const InputDecoration(
                      labelText: 'Latitud',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: longitudController,
                    readOnly: false,
                    decoration: const InputDecoration(
                      labelText: 'Longitud',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      onPressed: _enviarAsistencia,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 4, 91, 108),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 50, vertical: 15),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: const Text(
                        'Enviar Asistencia',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
