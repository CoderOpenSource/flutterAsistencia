import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:mapas_api/screens/home_pasajero.dart';
import 'package:mapas_api/screens/user/login_user.dart';
import 'package:mapas_api/screens/workshop/asistencias.dart';
import 'package:mapas_api/screens/workshop/atrasos.dart';
import 'package:mapas_api/screens/workshop/faltas.dart';
import 'package:mapas_api/screens/workshop/licencias_view.dart';
import 'package:mapas_api/screens/workshop/programaciones_academicas_hoy.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProgramacionesAcademicasScreen extends StatefulWidget {
  const ProgramacionesAcademicasScreen({Key? key}) : super(key: key);

  @override
  _ProgramacionesAcademicasScreen createState() =>
      _ProgramacionesAcademicasScreen();
}

class _ProgramacionesAcademicasScreen
    extends State<ProgramacionesAcademicasScreen> {
  String? firstName;
  String? lastName;
  late Future<List<ProgramacionAcademica>> programaciones;
  late Future<List<Materia>> materias;
  late Future<List<SesionClase>> sesionesClase;
  late Future<List<Aula>> aulas;

  @override
  void initState() {
    super.initState();
    programaciones = fetchProgramaciones();
    materias = fetchMaterias();
    sesionesClase = fetchSesionesClase();
    aulas = fetchAulas();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');

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
        print('Error en la respuesta de la API: ${response.statusCode}');
      }
    } else {
      print('User ID no disponible en SharedPreferences');
    }
  }

  Future<List<ProgramacionAcademica>> fetchProgramaciones() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId');

    final response = await http
        .get(Uri.parse('http://165.227.100.249/programacionesacademicas/'));
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse
          .map((programacion) => ProgramacionAcademica.fromJson(programacion))
          .where((programacion) => programacion.docenteIds.contains(userId))
          .toList();
    } else {
      throw Exception('Failed to load programaciones');
    }
  }

  Future<List<Materia>> fetchMaterias() async {
    final response =
        await http.get(Uri.parse('http://165.227.100.249/materias/'));
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((materia) => Materia.fromJson(materia)).toList();
    } else {
      throw Exception('Failed to load materias');
    }
  }

  Future<List<SesionClase>> fetchSesionesClase() async {
    final response =
        await http.get(Uri.parse('http://165.227.100.249/sesionesclase/'));
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse
          .map((sesion) => SesionClase.fromJson(sesion))
          .toList();
    } else {
      throw Exception('Failed to load sesiones clase');
    }
  }

  Future<List<Aula>> fetchAulas() async {
    final response = await http.get(Uri.parse('http://165.227.100.249/aulas/'));
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((aula) => Aula.fromJson(aula)).toList();
    } else {
      throw Exception('Failed to load aulas');
    }
  }

  String getMateriaNombre(int materiaId, List<Materia> materias) {
    final materia = materias.firstWhere((materia) => materia.id == materiaId,
        orElse: () => Materia(id: 0, nombre: 'Desconocido'));
    return materia.nombre;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Programaciones Académicas'),
        backgroundColor: const Color.fromARGB(255, 4, 91, 108),
      ),
      drawer: _buildDrawer(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(255, 5, 119, 142),
              Color.fromARGB(255, 98, 198, 232),
            ],
          ),
        ),
        child: FutureBuilder<List<ProgramacionAcademica>>(
          future: programaciones,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else {
              return FutureBuilder<List<Materia>>(
                future: materias,
                builder: (context, materiaSnapshot) {
                  if (materiaSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (materiaSnapshot.hasError) {
                    return Center(
                        child: Text('Error: ${materiaSnapshot.error}'));
                  } else {
                    return FutureBuilder<List<SesionClase>>(
                      future: sesionesClase,
                      builder: (context, sesionSnapshot) {
                        if (sesionSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        } else if (sesionSnapshot.hasError) {
                          return Center(
                              child: Text('Error: ${sesionSnapshot.error}'));
                        } else {
                          return FutureBuilder<List<Aula>>(
                            future: aulas,
                            builder: (context, aulaSnapshot) {
                              if (aulaSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              } else if (aulaSnapshot.hasError) {
                                return Center(
                                    child:
                                        Text('Error: ${aulaSnapshot.error}'));
                              } else {
                                return ListView.builder(
                                  itemCount: snapshot.data!.length,
                                  itemBuilder: (context, index) {
                                    var programacion = snapshot.data![index];
                                    var materiaNombre = getMateriaNombre(
                                        programacion.materiaId,
                                        materiaSnapshot.data!);
                                    return Card(
                                      color: Colors.white.withOpacity(0.85),
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 10, horizontal: 15),
                                      elevation: 8,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 15, horizontal: 20),
                                        leading: Icon(
                                          Icons.book,
                                          color: Colors.blue[800],
                                          size: 40,
                                        ),
                                        title: Text(
                                          materiaNombre,
                                          style: TextStyle(
                                            color: Colors.deepPurple[900],
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Grupo: ${programacion.grupo}',
                                              style: TextStyle(
                                                color: Colors.grey[700],
                                                fontSize: 16,
                                              ),
                                            ),
                                            ...programacion.sesionClaseIds
                                                .map((sesionId) {
                                              var sesion = sesionSnapshot.data!
                                                  .firstWhere(
                                                      (s) => s.id == sesionId,
                                                      orElse: () => SesionClase(
                                                          id: 0,
                                                          diaSemana: '',
                                                          horaInicio: '',
                                                          horaFin: '',
                                                          programacionAcademicaIds: []));
                                              return Text(
                                                '${sesion.diaSemana}: ${sesion.horaInicio} - ${sesion.horaFin}',
                                                style: TextStyle(
                                                  color: Colors.grey[700],
                                                  fontSize: 16,
                                                ),
                                              );
                                            }).toList(),
                                          ],
                                        ),
                                        onTap: () {
                                          // No hacer nada al hacer clic
                                        },
                                      ),
                                    );
                                  },
                                );
                              }
                            },
                          );
                        }
                      },
                    );
                  }
                },
              );
            }
          },
        ),
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
    prefs.remove('accessToken');
    prefs.remove('accessRefresh');
    prefs.remove('userId');

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (BuildContext context) =>
            const LoginView(), // Assuming your login view is named LoginView
      ),
      (Route<dynamic> route) => false, // This will remove all other screens
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

class SesionClase {
  final int id;
  final String diaSemana;
  final String horaInicio;
  final String horaFin;
  final List<int> programacionAcademicaIds;

  SesionClase({
    required this.id,
    required this.diaSemana,
    required this.horaInicio,
    required this.horaFin,
    required this.programacionAcademicaIds,
  });

  factory SesionClase.fromJson(Map<String, dynamic> json) {
    return SesionClase(
      id: json['id'],
      diaSemana: json['diaSemana'],
      horaInicio: json['horaInicio'],
      horaFin: json['horaFin'],
      programacionAcademicaIds:
          List<int>.from(json['programacionAcademicaIds']),
    );
  }
}
