import 'package:flutter/material.dart';
import 'package:mobile/services/api_service.dart';

class AddEstacionScreen extends StatefulWidget {
  const AddEstacionScreen({super.key});

  @override
  State<AddEstacionScreen> createState() => _AddEstacionScreenState();
}

class _AddEstacionScreenState extends State<AddEstacionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _ubicacionController = TextEditingController();

  void _guardar() async {
    if (_formKey.currentState!.validate()) {
      bool success = await ApiService().crearEstacion(
        _nombreController.text,
        _ubicacionController.text,
      );
      
      if (success) {
        if (mounted) {
          Navigator.pop(context, true); // Regresa al Dashboard
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: No autorizado o Servidor caído'),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _ubicacionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Estación'),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              TextFormField(
                controller: _ubicacionController,
                decoration: const InputDecoration(labelText: 'Ubicación'),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _guardar, 
                child: const Text('Guardar Estación'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}