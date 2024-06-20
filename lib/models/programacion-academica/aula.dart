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
