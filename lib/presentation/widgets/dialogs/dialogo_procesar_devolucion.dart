import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

class DialogoProcesarDevolucion extends StatefulWidget {
  final String title;
  final String detalle;
  final double montoRecibido;
  final double sugerencia;
  final String labelMonto;

  const DialogoProcesarDevolucion({
    super.key,
    required this.title,
    required this.detalle,
    required this.montoRecibido,
    required this.sugerencia,
    this.labelMonto = 'Monto a devolver (\$)',
  });

  @override
  State<DialogoProcesarDevolucion> createState() => _DialogoProcesarDevolucionState();
}

class _DialogoProcesarDevolucionState extends State<DialogoProcesarDevolucion> {
  late TextEditingController _montoController;

  @override
  void initState() {
    super.initState();
    _montoController = TextEditingController(text: widget.sugerencia.toStringAsFixed(2));
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: AlertDialog(
        backgroundColor: const Color.fromARGB(255, 49, 49, 49),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.detalle, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 10),
            Text('Precio original: \$${widget.montoRecibido.toStringAsFixed(2)}', 
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
            Text('Sugerencia prorrateada: \$${widget.sugerencia.toStringAsFixed(2)}', 
                style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: _montoController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: widget.labelMonto,
                labelStyle: const TextStyle(color: Colors.white60),
                enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            style: TextButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 20)),
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 10),
          TextButton(
            style: TextButton.styleFrom(backgroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20)),
            onPressed: () {
              final val = double.tryParse(_montoController.text);
              Navigator.of(context).pop(val);
            },
            child: const Text('Confirmar', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}