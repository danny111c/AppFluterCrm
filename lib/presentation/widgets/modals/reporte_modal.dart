import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/models/venta_model.dart';

class ReporteModal extends StatelessWidget {
  final Venta venta;
  final Function(String, bool) onReport;
  final List<Venta> ventasRelacionadas;

  const ReporteModal({
    super.key,
    required this.venta,
    required this.onReport,
    required this.ventasRelacionadas,
  });

  @override
  Widget build(BuildContext context) {
    String? tipoProblema;
    bool afectaATodas = false;
    
    return AlertDialog(
      title: const Text('Reportar Problema', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tipo de problema:', style: TextStyle(fontSize: 16)),
            DropdownButtonFormField<String>(
              items: const [
                DropdownMenuItem(value: 'cuenta_caida', child: Text('Cuenta caída')),
                DropdownMenuItem(value: 'credenciales_invalidas', child: Text('Credenciales inválidas')),
                DropdownMenuItem(value: 'cambio_clave', child: Text('Cambio de clave')),
              ],
              onChanged: (value) => tipoProblema = value,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            if(ventasRelacionadas.isNotEmpty)
              CheckboxListTile(
                title: const Text('Afecta a todas las ventas de esta cuenta'),
                value: afectaATodas,
                onChanged: (value) => afectaATodas = value ?? false,
              ),
            const SizedBox(height: 10),
            Text(
              'Fecha y hora: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if(tipoProblema != null) {
              onReport(tipoProblema!, afectaATodas);
              Navigator.pop(context);
            }
          },
          child: const Text('Reportar'),
        ),
      ],
    );
  }
}
