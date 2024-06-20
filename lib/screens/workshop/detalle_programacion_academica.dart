import 'package:flutter/material.dart';
import 'package:mapas_api/models/programacion-academica/programacion-academica.dart';
import 'package:mapas_api/models/programacion-academica/sesion_clase.dart';
import 'package:mapas_api/models/programacion-academica/aula.dart';

class DetalleProgramacionScreen extends StatelessWidget {
  final ProgramacionAcademica programacion;
  final String materiaNombre;
  final List<Aula> aulas;
  final List<SesionClase> sesionesClase;

  const DetalleProgramacionScreen({super.key, 
    required this.programacion,
    required this.materiaNombre,
    required this.aulas,
    required this.sesionesClase,
  });

  String getAulaNombre(int aulaId) {
    final aula = aulas.firstWhere((a) => a.id == aulaId,
        orElse: () => Aula(id: 0, nombre: 'Desconocido'));
    return aula.nombre;
  }

  bool isSesionHoy(SesionClase sesion) {
    final diasSemana = {
      'MONDAY': 1,
      'TUESDAY': 2,
      'WEDNESDAY': 3,
      'THURSDAY': 4,
      'FRIDAY': 5,
      'SATURDAY': 6,
      'SUNDAY': 7,
    };
    final hoy = DateTime.now().weekday;
    return diasSemana[sesion.diaSemana.toUpperCase()] == hoy;
  }

  @override
  Widget build(BuildContext context) {
    var sesionHoy = sesionesClase.firstWhere(
      (sesion) =>
          sesion.programacionAcademicaIds.contains(programacion.id) &&
          isSesionHoy(sesion),
      orElse: () => SesionClase(
        id: 0,
        diaSemana: '',
        horaInicio: '',
        horaFin: '',
        programacionAcademicaIds: [],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles de Programación Académica'),
        backgroundColor: const Color.fromARGB(255, 4, 91, 108),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Materia: $materiaNombre',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Aula: ${getAulaNombre(programacion.aulaId)}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            if (sesionHoy.id != 0)
              Text(
                'Sesión de hoy: ${sesionHoy.horaInicio} - ${sesionHoy.horaFin}',
                style: const TextStyle(fontSize: 16),
              ),
            const SizedBox(height: 10),
            Text(
              'Grupo: ${programacion.grupo}',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
