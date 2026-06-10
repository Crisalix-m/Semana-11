class Estacion {
  final int id;
  final String nombre;
  final String ubicacion;
  final int? ultimaLectura; // 1. Agregamos el campo opcional para el reto

  Estacion({
    required this.id, 
    required this.nombre, 
    required this.ubicacion,
    this.ultimaLectura, // 2. Lo sumamos al constructor como opcional
  });

  factory Estacion.fromJson(Map<String, dynamic> json) {
    return Estacion(
      id: json['id'],
      nombre: json['nombre'],
      ubicacion: json['ubicacion'],
      // 3. Lo mapeamos desde el JSON (si viene como 'ultima_lectura' o 'lectura' en tu API, cambia el texto de los corchetes)
      ultimaLectura: json['ultima_lectura'] ?? json['lectura'], 
    );
  }
}