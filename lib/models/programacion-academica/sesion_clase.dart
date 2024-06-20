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
