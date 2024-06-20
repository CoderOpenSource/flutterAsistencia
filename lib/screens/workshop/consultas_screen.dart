import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PendingConsultationsScreen extends StatefulWidget {
  const PendingConsultationsScreen({super.key});

  @override
  _PendingConsultationsScreenState createState() =>
      _PendingConsultationsScreenState();
}

class _PendingConsultationsScreenState
    extends State<PendingConsultationsScreen> {
  late Future<List<Consultation>> consultations;
  late int userId;

  @override
  void initState() {
    super.initState();
    consultations = _loadUserIdAndFetchConsultations();
  }

  Future<List<Consultation>> _loadUserIdAndFetchConsultations() async {
    final prefs = await SharedPreferences.getInstance();
    final userIdString = prefs.getString('userId');
    final userId = int.parse(userIdString!);
    print(userId);
    return fetchConsultations(userId);
  }

  Future<List<Consultation>> fetchConsultations(int userId) async {
    final response = await http.get(
      Uri.parse('http://192.168.0.15/consultations/consultations/'),
    );

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      List<Consultation> allConsultations = jsonResponse
          .map((consultation) => Consultation.fromJson(consultation))
          .toList();

      // Filtrar las consultas para el usuario actual
      List<Consultation> userConsultations = allConsultations
          .where((consultation) => consultation.patientId == userId)
          .toList();

      // Obtener detalles adicionales para cada consulta
      for (var consultation in userConsultations) {
        await fetchAdditionalDetails(consultation);
      }

      return userConsultations;
    } else {
      throw Exception('Failed to load consultations');
    }
  }

  Future<void> fetchAdditionalDetails(Consultation consultation) async {
    // Obtener detalles del doctor
    final doctorResponse = await http.get(
      Uri.parse(
          'http://192.168.0.15/scheduling/schedules/${consultation.scheduleId}/'),
    );

    if (doctorResponse.statusCode == 200) {
      var doctorJson = json.decode(doctorResponse.body);
      consultation.doctorName = doctorJson['doctor']['user']['first_name'] +
          ' ' +
          doctorJson['doctor']['user']['last_name'];
      consultation.scheduleTime = doctorJson['start_time'];
    } else {
      throw Exception('Failed to load doctor details');
    }

    // Obtener detalles del servicio
    final serviceResponse = await http.get(
      Uri.parse(
          'http://192.168.0.15/medical/services/${consultation.serviceId}/'),
    );

    if (serviceResponse.statusCode == 200) {
      var serviceJson = json.decode(serviceResponse.body);
      consultation.serviceName = serviceJson['name'];
    } else {
      throw Exception('Failed to load service details');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultas Pendientes'),
        backgroundColor: const Color.fromARGB(255, 43, 29, 45), // Lila oscuro
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(255, 43, 29, 45), // Lila oscuro
              Color.fromARGB(255, 201, 187, 187), // Lila claro
            ],
          ),
        ),
        child: FutureBuilder<List<Consultation>>(
          future: consultations,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else {
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  return Card(
                    color: Colors.white70, // Color de fondo de la tarjeta
                    margin: const EdgeInsets.all(10),
                    elevation: 5, // Sombra de la tarjeta
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(15), // Bordes redondeados
                    ),
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                      title: Text(
                        'Doctor: ${snapshot.data![index].doctorName}',
                        style: TextStyle(
                          color: Colors
                              .deepPurple[800], // Color del texto del título
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Servicio: ${snapshot.data![index].serviceName}\n'
                        'Horario: ${snapshot.data![index].scheduleTime}\n'
                        'Fecha: ${snapshot.data![index].date}',
                        style: const TextStyle(
                          color: Colors
                              .black54, // Color del texto de la descripción
                        ),
                      ),
                    ),
                  );
                },
              );
            }
          },
        ),
      ),
    );
  }
}

class Consultation {
  final int id;
  final String date;
  final int patientId;
  final int doctorId;
  final int serviceId;
  final int consultingRoomId;
  final int scheduleId;
  String? doctorName;
  String? serviceName;
  String? scheduleTime;

  Consultation({
    required this.id,
    required this.date,
    required this.patientId,
    required this.doctorId,
    required this.serviceId,
    required this.consultingRoomId,
    required this.scheduleId,
  });

  factory Consultation.fromJson(Map<String, dynamic> json) {
    return Consultation(
      id: json['id'],
      date: json['date'],
      patientId: json['patient'],
      doctorId: json['doctor'],
      serviceId: json['service'],
      consultingRoomId: json['consulting_room'],
      scheduleId: json['schedule'],
    );
  }
}
