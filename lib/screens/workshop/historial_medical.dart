import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mapas_api/screens/workshop/historial_medical_detail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MedicalHistoryScreen extends StatefulWidget {
  const MedicalHistoryScreen({super.key});

  @override
  _MedicalHistoryScreenState createState() => _MedicalHistoryScreenState();
}

class _MedicalHistoryScreenState extends State<MedicalHistoryScreen> {
  late Future<List<MedicalHistory>> _medicalHistories;

  @override
  void initState() {
    super.initState();
    _medicalHistories = _fetchMedicalHistory();
  }

  Future<List<MedicalHistory>> _fetchMedicalHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');

    if (userId == null) {
      throw Exception('User ID not found in SharedPreferences');
    }

    final response = await http.get(
      Uri.parse('http://192.168.0.15/historical_medical/medical_histories/'),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(utf8.decode(response.bodyBytes));
      List<MedicalHistory> allHistories = jsonResponse
          .map((history) => MedicalHistory.fromJson(history))
          .toList();

      // Filtrar los historiales médicos basados en el paciente
      List<MedicalHistory> patientHistories =
          allHistories.where((history) => history.patient == userId).toList();

      return patientHistories;
    } else {
      throw Exception('Failed to load medical history');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial Médico'),
        backgroundColor: const Color.fromARGB(255, 43, 29, 45),
      ),
      body: FutureBuilder<List<MedicalHistory>>(
        future: _medicalHistories,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay historial médico disponible.'));
          } else {
            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final history = snapshot.data![index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  elevation: 4,
                  child: ListTile(
                    title: Text('Fecha: ${history.date}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text('Síntomas: ${history.symptoms}'),
                        Text('Diagnóstico: ${history.diagnosis}'),
                        Text('Tratamiento: ${history.treatment}'),
                        Text('Notas: ${history.notes}'),
                        Text('Fecha de seguimiento: ${history.followUpDate}'),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                MedicalHistoryDetailScreen(history: history),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}

class MedicalHistory {
  final int id;
  final String date;
  final String symptoms;
  final String diagnosis;
  final String treatment;
  final String followUpDate;
  final String notes;
  final int patient;
  final int doctor;
  final int prescription;

  MedicalHistory({
    required this.id,
    required this.date,
    required this.symptoms,
    required this.diagnosis,
    required this.treatment,
    required this.followUpDate,
    required this.notes,
    required this.patient,
    required this.doctor,
    required this.prescription,
  });

  factory MedicalHistory.fromJson(Map<String, dynamic> json) {
    return MedicalHistory(
      id: json['id'],
      date: json['date'],
      symptoms: json['symptoms'],
      diagnosis: json['diagnosis'],
      treatment: json['treatment'],
      followUpDate: json['follow_up_date'],
      notes: json['notes'],
      patient: json['patient'],
      doctor: json['doctor'],
      prescription: json['prescription'],
    );
  }
}
