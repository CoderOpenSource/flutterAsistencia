import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mapas_api/screens/home_pasajero.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class GenerarLicenciaScreen extends StatefulWidget {
  final int programacionAcademicaId;

  const GenerarLicenciaScreen(
      {super.key, required this.programacionAcademicaId});

  @override
  _GenerarLicenciaScreenState createState() => _GenerarLicenciaScreenState();
}

class _GenerarLicenciaScreenState extends State<GenerarLicenciaScreen> {
  TextEditingController motivoController = TextEditingController();
  TextEditingController fechaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    final String fechaFormateada = DateFormat('yyyy-MM-dd').format(now);
    fechaController.text = fechaFormateada;
  }

  @override
  void dispose() {
    motivoController.dispose();
    fechaController.dispose();
    super.dispose();
  }

  Future<void> _enviarLicencia() async {
    final prefs = await SharedPreferences.getInstance();
    final docenteId = prefs.getInt('userId');
    if (docenteId == null) {
      // Manejar el caso en que el docenteId no esté disponible
      return;
    }

    final DateTime now = DateTime.now();
    final String fecha = now.toIso8601String();

    final licencia = {
      'programacionAcademicaId': widget.programacionAcademicaId,
      'docenteId': docenteId,
      'fecha': fecha,
      'motivo': motivoController.text,
      'fotoLicencia': null
    };

    var uri = Uri.parse('http://165.227.100.249/licencias/createOrUpdate');
    var request = http.MultipartRequest('POST', uri);

    request.files.add(http.MultipartFile.fromString(
      'licencia',
      jsonEncode(licencia),
      contentType: MediaType('application', 'json'),
    ));

    var response = await request.send();

    if (response.statusCode == 200) {
      // Licencia enviada exitosamente
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Licencia enviada exitosamente',
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
      final responseBody = await response.stream.bytesToString();
      print('Error al enviar la licencia: ${response.statusCode}');
      print('Response body: $responseBody');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al enviar la licencia'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generar Licencia'),
        backgroundColor: const Color.fromARGB(255, 4, 91, 108),
      ),
      body: Padding(
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
              controller: motivoController,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _enviarLicencia,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 4, 91, 108),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Text(
                  'Enviar Licencia',
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
