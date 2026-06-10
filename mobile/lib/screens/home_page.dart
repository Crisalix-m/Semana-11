import 'dart:async'; // <--- 1. ¡SUPER IMPORTANTE! Importación necesaria para el Timer
import 'package:flutter/material.dart';
import 'package:mobile/models/estacion.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_service.dart';
import 'add_estacion.dart';
import 'login_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<Estacion>> _futureEstaciones;
  final ApiService apiService = ApiService(); 
  Timer? _refreshTimer; // <--- 2. Variable global para controlar el temporizador automático

  @override
  void initState() {
    super.initState();
    _refreshEstaciones();

    // 3. ENTRADA EN TIEMPO REAL (AUTOREFRESCO CADA 3 SEGUNDOS)
    // Esto fuerza a que se vuelvan a pedir las lecturas a FastAPI sin parpadear la pantalla
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          // Re-ejecuta el build() actualizando los FutureBuilder con datos nuevos de Python
        });
      }
    });
  }

  @override
  void dispose() {
    // 4. MUY CRÍTICO: Limpiamos el Timer al salir o desarmar la pantalla 
    // para evitar fugas de memoria importantes.
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _refreshEstaciones() {
    setState(() {
      _futureEstaciones = ApiService().fetchEstaciones();
    });
  }

  void _logout() async {
    _refreshTimer?.cancel(); // Cancelamos también al cerrar sesión por seguridad
    await AuthService().logout();
    
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  // ==========================================
  // DIÁLOGO DE EDICIÓN (Mantenido intacto)
  // ==========================================
  void _mostrarDialogoEdicion(Estacion estacion) {
    final nombreCtrl = TextEditingController(text: estacion.nombre);
    final ubicacionCtrl = TextEditingController(text: estacion.ubicacion);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Editar Estación"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl, 
              decoration: const InputDecoration(labelText: "Nombre")
            ),
            TextField(
              controller: ubicacionCtrl, 
              decoration: const InputDecoration(labelText: "Ubicación")
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              bool ok = await apiService.editarEstacion(
                estacion.id, 
                nombreCtrl.text, 
                ubicacionCtrl.text
              );
              
              if (ok) {
                if (!context.mounted) return;
                Navigator.pop(context); 
                _refreshEstaciones();  
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Estación actualizada correctamente")),
                );
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  // ======================================================================
  // FUNCIÓN AUXILIAR: Obtiene las lecturas inyectando el Token en tiempo de ejecución
  // ======================================================================
  Future<List<dynamic>> _obtenerLecturasAutenticadas() async {
    return await apiService.fetchLecturas(); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estaciones SMAT'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: _logout,
          ),
        ],
      ),
      body: FutureBuilder<List<Estacion>>(
        future: _futureEstaciones,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay estaciones registradas.'));
          }

          final estaciones = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _refreshEstaciones(), 
            child: ListView.builder(
              itemCount: estaciones.length,
              itemBuilder: (context, index) {
                final estacion = estaciones[index];
                
                // USAMOS LA FUNCIÓN AUTENTICADA EN EL FUTUREBUILDER
                return FutureBuilder<List<dynamic>>(
                  future: _obtenerLecturasAutenticadas(), 
                  builder: (context, lecturaSnapshot) {
                    String valorTexto = "0.0 cm";
                    bool esCritico = false;

                    if (lecturaSnapshot.hasData && lecturaSnapshot.data!.isNotEmpty) {
                      // FILTRADO ROBUSTO: Comparación estricta de IDs transformados a String
                      final lecturasDeEstaEstacion = lecturaSnapshot.data!.where((l) {
                        final idEstacionLectura = l['estacion_id'] ?? l['estacionId'];
                        return idEstacionLectura.toString() == estacion.id.toString();
                      }).toList();

                      if (lecturasDeEstaEstacion.isNotEmpty) {
                        // Tomamos la telemetría más reciente generada por sensor_emitter.py
                        final ultimaLectura = lecturasDeEstaEstacion.last;
                        final double valor = double.tryParse(ultimaLectura['valor'].toString()) ?? 0.0;
        
                        valorTexto = "${valor.toStringAsFixed(1)} cm";
        
                        // CAMBIO DE COLOR DINÁMICO (SI SUPERA LOS 70.0 CM)
                        if (valor > 70.0) {
                          esCritico = true;
                        }
                      }
                    }

                    // SWIPE-TO-DISMISS (DESLIZAR PARA BORRAR)
                    return Dismissible(
                      key: Key(estacion.id.toString()),
                      direction: DismissDirection.endToStart, 
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (direction) async {
                        final nombreEstacion = estacion.nombre;
                        bool ok = await apiService.eliminarEstacion(estacion.id);
                        
                        if (ok) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("$nombreEstacion eliminada")),
                          );
                        } else {
                          _refreshEstaciones();
                        }
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        color: esCritico ? Colors.red.shade50 : Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: esCritico ? Colors.red.shade100 : Colors.green.shade100,
                            child: Icon(
                              Icons.wifi_tethering, 
                              color: esCritico ? Colors.red : Colors.green,
                            ),
                          ),
                          title: Text(
                            estacion.nombre,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: esCritico ? Colors.red.shade900 : Colors.black87,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                "Valor actual: $valorTexto",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: esCritico ? Colors.red.shade700 : Colors.blue.shade700,
                                ),
                              ),
                              Text(
                                    estacion.ubicacion,
                                style: const TextStyle(color: Colors.black54, fontSize: 13),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.black45), 
                            onPressed: () => _mostrarDialogoEdicion(estacion), 
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final resultado = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddEstacionScreen()),
          );
          if (resultado == true) {
            _refreshEstaciones();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}