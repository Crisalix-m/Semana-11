import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/home_page.dart';
import 'services/auth_service.dart';

void main() => runApp(const SMATApp());

class SMATApp extends StatelessWidget {
  const SMATApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SMAT Mobile',
      // El home ahora depende de la verificación del token en SharedPreferences
      home: FutureBuilder<String?>(
        future: AuthService().getToken(),
        builder: (context, snapshot) {
          // Mientras verifica la memoria interna, muestra un indicador de carga
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // Si el token existe y no es nulo, entra directo al HomePage (Dashboard)
          if (snapshot.hasData && snapshot.data != null) {
            return const HomePage(); 
          }

          // Si no hay token guardado, lo redirige al Login de manera automática
          return const LoginScreen();
        },
      ),
    );
  }
}