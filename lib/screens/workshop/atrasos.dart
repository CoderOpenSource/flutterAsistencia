import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mapas_api/screens/home_pasajero.dart';
import 'package:mapas_api/screens/user/login_user.dart';
import 'package:mapas_api/screens/workshop/asistencias.dart';
import 'package:mapas_api/screens/workshop/faltas.dart';
import 'package:mapas_api/screens/workshop/licencias_view.dart';
import 'package:mapas_api/screens/workshop/programaciones_academicas.dart';
import 'package:mapas_api/screens/workshop/programaciones_academicas_hoy.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AtrasosDocenteScreen extends StatefulWidget {
  const AtrasosDocenteScreen({super.key});

  @override
  _AtrasosDocenteScreenState createState() => _AtrasosDocenteScreenState();
}

class _AtrasosDocenteScreenState extends State<AtrasosDocenteScreen> {
  late List<Asistencia> asistencias = [];
  late Future<void> futureAsistencias;
  List<Materia> materias = [];
  List<ProgramacionAcademica> programaciones = [];
  String? firstName;

  String? lastName;
  @override
  void initState() {
    super.initState();
    futureAsistencias = fetchAsistencias();
    fetchMaterias();
    fetchProgramaciones();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();

    final userId = prefs.getInt('userId'); // Aquí lo recuperamos como entero

    if (userId != null) {
      final response =
          await http.get(Uri.parse('http://165.227.100.249/docentes/$userId'));

      if (response.statusCode == 200) {
        final data = json
            .decode(utf8.decode(response.bodyBytes)); // Decodificar como UTF-8

        setState(() {
          firstName = data['nombre'];

          lastName = data['apellido'];
        });
      } else {
        // Manejar error de respuesta de la API

        print('Error en la respuesta de la API: ${response.statusCode}');
      }
    } else {
      // Manejar caso donde userId no está disponible

      print('User ID no disponible en SharedPreferences');
    }
  }

  Future<void> fetchAsistencias() async {
    final prefs = await SharedPreferences.getInstance();
    final docenteId = prefs.getInt('userId');
    if (docenteId == null) {
      return;
    }

    final response =
        await http.get(Uri.parse('http://165.227.100.249/asistencias/'));

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      setState(() {
        asistencias = jsonResponse
            .map((asistencia) => Asistencia.fromJson(asistencia))
            .where((asistencia) =>
                asistencia.docenteId == docenteId &&
                asistencia.estadoAsistenciaId == 2)
            .toList();
      });
    } else {
      throw Exception('Failed to load asistencias');
    }
  }

  Future<void> fetchMaterias() async {
    final response =
        await http.get(Uri.parse('http://165.227.100.249/materias/'));

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      setState(() {
        materias =
            jsonResponse.map((materia) => Materia.fromJson(materia)).toList();
      });
    } else {
      throw Exception('Failed to load materias');
    }
  }

  Future<void> fetchProgramaciones() async {
    final response = await http
        .get(Uri.parse('http://165.227.100.249/programacionesacademicas/'));

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      setState(() {
        programaciones = jsonResponse
            .map((programacion) => ProgramacionAcademica.fromJson(programacion))
            .toList();
      });
    } else {
      throw Exception('Failed to load programaciones');
    }
  }

  String getMateriaNombre(int programacionId) {
    final programacion = programaciones.firstWhere(
        (programacion) => programacion.id == programacionId,
        orElse: () => ProgramacionAcademica(
            id: 0,
            materiaId: 0,
            aulaId: 0,
            docenteIds: [],
            sesionClaseIds: [],
            grupo: 'Desconocido'));
    final materia = materias.firstWhere(
        (materia) => materia.id == programacion.materiaId,
        orElse: () => Materia(id: 0, nombre: 'Desconocido'));
    return materia.nombre;
  }

  String getGrupoNombre(int programacionId) {
    final programacion = programaciones.firstWhere(
        (programacion) => programacion.id == programacionId,
        orElse: () => ProgramacionAcademica(
            id: 0,
            materiaId: 0,
            aulaId: 0,
            docenteIds: [],
            sesionClaseIds: [],
            grupo: 'Desconocido'));
    return programacion.grupo;
  }

  String formatFecha(String fecha) {
    final DateTime dateTime = DateTime.parse(fecha);
    return DateFormat('yyyy-MM-dd – kk:mm').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Atrasos del Docente'),
        backgroundColor: const Color.fromARGB(255, 4, 91, 108),
      ),
      drawer: _buildDrawer(),
      body: FutureBuilder<void>(
        future: futureAsistencias,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            return ListView.builder(
              itemCount: asistencias.length,
              itemBuilder: (context, index) {
                var asistencia = asistencias[index];
                var materiaNombre =
                    getMateriaNombre(asistencia.programacionAcademicaId);
                var grupoNombre =
                    getGrupoNombre(asistencia.programacionAcademicaId);
                var fechaFormateada = formatFecha(asistencia.fecha);

                return Card(
                  color: Colors.white.withOpacity(0.85),
                  margin:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 15, horizontal: 20),
                    leading: Icon(
                      Icons.warning,
                      color: Colors.orange[800],
                      size: 40,
                    ),
                    title: Text(
                      'Materia: $materiaNombre',
                      style: TextStyle(
                        color: Colors.deepPurple[900],
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Grupo: $grupoNombre',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Fecha: $fechaFormateada',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Observaciones: ${asistencia.observaciones}',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      // Aquí puedes agregar la navegación a una pantalla de detalles, si es necesario
                    },
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(255, 4, 91, 108), // Lila oscuro

              Color.fromARGB(255, 134, 202, 227), // Blanco
            ],
          ),
        ),
        child: ListView(
          children: <Widget>[
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color.fromARGB(
                    255, 4, 91, 108), // Lila oscuro para el DrawerHeader
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey[200],
                    child:
                        const Icon(Icons.person, size: 50, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    firstName != null && lastName != null
                        ? '$firstName $lastName'
                        : 'Nombre no disponible',
                    style: const TextStyle(color: Colors.white, fontSize: 24.0),
                  ),
                ],
              ),
            ),
            _buildDrawerItem(Icons.home, 'Home', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => (const MapScreen())),
              );
            }),
            _buildDrawerItem(
                Icons.calendar_today_outlined, 'Ver Programaciones Academicas',
                () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        (const ProgramacionesAcademicasScreen())),
              );
            }),
            _buildDrawerItem(
                Icons.alarm, 'Ver Programaciones Academicas de Hoy!', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        (const ProgramacionesAcademicasHoyScreen())),
              );
            }),
            _buildDrawerItem(Icons.history, 'Ver Asistencias', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AsistenciasDocenteScreen()),
              );
            }),
            _buildDrawerItem(Icons.warning, 'Ver Atrasos', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AtrasosDocenteScreen()),
              );
            }),
            _buildDrawerItem(Icons.close, 'Ver Faltas', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const FaltasDocenteScreen()),
              );
            }),
            _buildDrawerItem(Icons.assignment, 'Ver Licencias', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const LicenciasDocenteScreen()),
              );
            }),
            _buildDrawerItem(Icons.settings, 'Configuración', () {}),
            _buildDrawerItem(Icons.help, 'Ayuda', () {
              // Implementar navegación a la pantalla de ayuda
            }),
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: () => _showLogoutConfirmation(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(
                      255, 4, 91, 108), // Lila oscuro para el botón

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text("Cerrar sesión",
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar'),
          content: const Text('¿Quieres cerrar sesión?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                _logout(context);
              },
              child: const Text('Sí'),
            ),
          ],
        );
      },
    );
  }

  void _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    // Remove the stored preferences

    prefs.remove('accessToken');

    prefs.remove('accessRefresh');

    prefs.remove('userId');

    // Navigate to the login page and remove all other screens from the navigation stack

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (BuildContext context) =>
            const LoginView(), // Assuming your login view is named LoginView
      ),

      (Route<dynamic> route) => false, // This will remove all other screens
    );
  }
}

class Asistencia {
  final int id;
  final int programacionAcademicaId;
  final int estadoAsistenciaId;
  final int docenteId;
  final String fecha;
  final String observaciones;
  final String? fotoUrl;
  final double latitud;
  final double longitud;

  Asistencia({
    required this.id,
    required this.programacionAcademicaId,
    required this.estadoAsistenciaId,
    required this.docenteId,
    required this.fecha,
    required this.observaciones,
    this.fotoUrl,
    required this.latitud,
    required this.longitud,
  });

  factory Asistencia.fromJson(Map<String, dynamic> json) {
    return Asistencia(
      id: json['id'],
      programacionAcademicaId: json['programacionAcademicaId'],
      estadoAsistenciaId: json['estadoAsistenciaId'],
      docenteId: json['docenteId'],
      fecha: json['fecha'],
      observaciones: json['observaciones'],
      fotoUrl: json['fotoUrl'],
      latitud: json['latitud'],
      longitud: json['longitud'],
    );
  }
}

class Materia {
  final int id;
  final String nombre;

  Materia({
    required this.id,
    required this.nombre,
  });

  factory Materia.fromJson(Map<String, dynamic> json) {
    return Materia(
      id: json['id'],
      nombre: json['nombre'],
    );
  }
}

class Aula {
  final int id;
  final String nombre;

  Aula({
    required this.id,
    required this.nombre,
  });

  factory Aula.fromJson(Map<String, dynamic> json) {
    return Aula(
      id: json['id'],
      nombre: json['nombre'],
    );
  }
}

class ProgramacionAcademica {
  final int id;
  final int materiaId;
  final int aulaId;
  final List<int> docenteIds;
  final List<int> sesionClaseIds;
  final String grupo;

  ProgramacionAcademica({
    required this.id,
    required this.materiaId,
    required this.aulaId,
    required this.docenteIds,
    required this.sesionClaseIds,
    required this.grupo,
  });

  factory ProgramacionAcademica.fromJson(Map<String, dynamic> json) {
    return ProgramacionAcademica(
      id: json['id'],
      materiaId: json['materiaId'],
      aulaId: json['aulaId'],
      docenteIds: List<int>.from(json['docenteIds']),
      sesionClaseIds: List<int>.from(json['sesionClaseIds']),
      grupo: json['grupo'],
    );
  }
}
