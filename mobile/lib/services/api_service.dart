import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mobile/models/estacion.dart';
import 'auth_service.dart'; 

class ApiService {
  // Nota: 10.0.2.2 es el localhost para el emulador Android.
  // Si usa Linux Desktop o Web, use 'localhost'.
  final String baseUrl = "http://localhost:8000";

  // 1. OBTENER ESTACIONES - ¡AHORA CON TRY-CATCH Y TIMEOUT!
  Future<List<Estacion>> fetchEstaciones() async {
    try {
      // Agregamos .timeout() de 5 segundos para evitar esperas infinitas si el servidor cae
      final response = await http.get(Uri.parse('$baseUrl/estaciones/'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body);
        return jsonResponse.map((data) => Estacion.fromJson(data)).toList();
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      // Este catch captura errores de red, fallas de conexión o cortes de servidor
      // Evita que la App se cierre inesperadamente y envía el mensaje limpio exigido
      throw Exception('No se pudo conectar con SMAT. ¿Está el servidor activo?');
    }
  }

  // Crear una nueva estación (POST)
  Future<bool> crearEstacion(String nombre, String ubicacion) async {
    final token = await AuthService().getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/estaciones/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'nombre': nombre, 'ubicacion': ubicacion}),
    );
    return response.statusCode == 200;
  }

  // Eliminar una estación (DELETE)
  Future<bool> eliminarEstacion(int id) async {
    final token = await AuthService().getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/estaciones/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response.statusCode == 200;
  }

  // Actualizar-Editar una estación (PUT)
  Future<bool> editarEstacion(int id, String nombre, String ubicacion) async {
    final token = await AuthService().getToken();
    
    final url = Uri.parse('$baseUrl/estaciones/$id?nombre=${Uri.encodeComponent(nombre)}&ubicacion=${Uri.encodeComponent(ubicacion)}');
    
    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    
    return response.statusCode == 200;
  }
  // ========================================================
  // NUEVA FUNCIÓN PARA EL RETO: OBTENER LECTURAS GLOBAL
  // ========================================================
Future<List<dynamic>> fetchLecturas() async {
    try {
      // 1. Recuperamos el token almacenado de forma segura al iniciar sesión
      final token = await AuthService().getToken();

      // 2. Hacemos el GET inyectando el Bearer token en las cabeceras
      final response = await http.get(
        Uri.parse('$baseUrl/lecturas/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // <--- ¡La llave para solucionar el 401!
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        // Decodificamos la respuesta JSON (que ahora sí traerá los datos)
        List<dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse;
      } else {
        print("El backend rechazó la solicitud. Código de estado: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Error al conectar con /lecturas/: $e");
      return []; // Devolvemos una lista vacía si falla la conexión
    }
  }
}