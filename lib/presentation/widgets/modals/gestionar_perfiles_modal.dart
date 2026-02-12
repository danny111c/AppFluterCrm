import 'package:flutter/material.dart';
import '../../../infrastructure/repositories/venta_repository.dart';

class GestionarPerfilesModal extends StatefulWidget {
  final String cuentaId;
  final String correo;

  const GestionarPerfilesModal({super.key, required this.cuentaId, required this.correo});

  @override
  State<GestionarPerfilesModal> createState() => _GestionarPerfilesModalState();
}

class _GestionarPerfilesModalState extends State<GestionarPerfilesModal> {
  final _ventaRepo = VentaRepository();
  bool _isLoading = true;
  List<Map<String, dynamic>> _perfiles = [];

  @override
  void initState() {
    super.initState();
    _cargarPerfiles();
  }

  Future<void> _cargarPerfiles() async {
    final data = await _ventaRepo.getTodosLosPerfilesDeCuenta(widget.cuentaId);
    setState(() {
      _perfiles = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text("Perfiles: ${widget.correo}", style: const TextStyle(color: Colors.white, fontSize: 16)),
      content: SizedBox(
        width: 500,
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              shrinkWrap: true,
              itemCount: _perfiles.length,
              itemBuilder: (context, index) {
                final perfil = _perfiles[index];
                final nombreController = TextEditingController(text: perfil['nombre_perfil']);
                final pinController = TextEditingController(text: perfil['pin']);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Expanded(child: TextField(controller: nombreController, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: const InputDecoration(labelText: "Nombre", labelStyle: TextStyle(color: Colors.grey)))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: pinController, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: const InputDecoration(labelText: "PIN", labelStyle: TextStyle(color: Colors.grey)))),
                      const SizedBox(width: 10),
                      Text(perfil['estado'].toUpperCase(), style: TextStyle(color: perfil['estado'] == 'disponible' ? Colors.green : Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.save, color: Colors.blueAccent, size: 20),
                        onPressed: () async {
// ✅ VALIDACIÓN DE SEGURIDAD
    final String nuevoNombre = nombreController.text.trim().toLowerCase();
    final String correoMaestro = widget.correo.trim().toLowerCase();

    if (nuevoNombre == correoMaestro) {
      // Si el usuario intenta poner el mismo correo, mostramos error y no guardamos
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ ERROR: No puedes usar el correo principal como nombre de perfil. Usa el correo del cliente."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return; // Detiene el proceso de guardado
    }

    // Si pasa la validación, guarda normalmente
    await _ventaRepo.actualizarPerfilMaestro(
      perfil['id'], 
      nombreController.text.trim(), 
      pinController.text.trim()
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Perfil Actualizado Correctamente"))
      );
    }
  },
),
                    ],
                  ),
                );
              },
            ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cerrar", style: TextStyle(color: Colors.white))),
      ],
    );
  }
}