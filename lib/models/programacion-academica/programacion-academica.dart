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
