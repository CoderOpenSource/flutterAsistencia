import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:mapas_api/blocs/location/location_bloc.dart';

import 'package:mapas_api/blocs/map/map_bloc.dart';

import 'package:mapas_api/screens/user/login_user.dart';

import 'package:mapas_api/screens/workshop/asistencias.dart';

import 'package:mapas_api/screens/workshop/atrasos.dart';

import 'package:mapas_api/screens/workshop/faltas.dart';

import 'package:mapas_api/screens/workshop/licencias_view.dart';

import 'package:mapas_api/screens/workshop/programaciones_academicas.dart';

import 'package:mapas_api/screens/workshop/programaciones_academicas_hoy.dart';

import 'package:mapas_api/views/map_view.dart';

import 'package:mapas_api/widgets/btn_follow_user.dart';

import 'package:mapas_api/widgets/btn_location.dart';

import 'package:mapas_api/widgets/btn_toggle_user_route.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:http/http.dart' as http;

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  late LocationBloc locationBloc;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String? firstName;

  String? lastName;

  @override
  void initState() {
    super.initState();

    DateTime now = DateTime.now();

    String fecha =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    String hora =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    print('Fecha actual: $fecha');

    print('Hora actual: $hora');

    locationBloc = BlocProvider.of<LocationBloc>(context);

    locationBloc.startFollowingUser();

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

  @override
  void dispose() {
    locationBloc.stopFollowingUser();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text("UnivSys"),

        backgroundColor:
            const Color.fromARGB(255, 4, 91, 108), // Lila oscuro para el AppBar

        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),

        centerTitle: true,
      ),
      drawer: _buildDrawer(),
      body: BlocBuilder<LocationBloc, LocationState>(
        builder: (context, locationState) {
          if (locationState.lastKnownLocation == null) {
            return const Center(child: Text('Espere por favor...'));
          }

          return BlocBuilder<MapBloc, MapState>(
            builder: (context, mapState) {
              Map<String, Polyline> polylines = Map.from(mapState.polylines);

              if (!mapState.showMyRoute) {
                polylines.removeWhere((key, value) => key == 'myRoute');
              }

              return SingleChildScrollView(
                child: Stack(
                  children: [
                    MapView(
                      initialLocation: locationState.lastKnownLocation!,
                      polylines: polylines.values.toSet(),
                      markers: mapState.markers.values.toSet(),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: const Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          BtnToggleUserRoute(),
          BtnFollowUser(),
          BtnCurrentLocation(),
        ],
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
      title: Text(title,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)),
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
