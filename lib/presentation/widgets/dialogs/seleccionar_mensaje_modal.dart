import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../domain/models/plantilla_model.dart';
import '../../../infrastructure/repositories/plantilla_repository.dart';

class SeleccionarMensajeModal extends StatefulWidget {
  final String title;
  final String phoneNumber;
  final Map<String, String> dataForVariables;
  final String tipoPlantilla; // 'cliente' o 'proveedor'
  final String categoriaDestino; // ✅ Nueva: 'clientes', 'ventas', 'cuentas' o 'proveedores'

  const SeleccionarMensajeModal({
    super.key,
    required this.title,
    required this.phoneNumber,
    required this.dataForVariables,
    required this.tipoPlantilla,
        required this.categoriaDestino, // ✅ AÑADE ESTA LÍNEA AQUÍ

  });

  @override
  State<SeleccionarMensajeModal> createState() => _SeleccionarMensajeModalState();
}

class _SeleccionarMensajeModalState extends State<SeleccionarMensajeModal> {
  final PlantillaRepository _plantillaRepo = PlantillaRepository();
  late Future<List<Plantilla>> _plantillasFuture;

  @override
  void initState() {
    super.initState();
    _plantillasFuture = _plantillaRepo.getPlantillas();
  }

  Future<void> _launchWhatsApp(String? message) async {
    final telefonoLimpio = widget.phoneNumber.replaceAll(RegExp(r'\D'), '');
    String urlString;

    if (message == null || message.isEmpty) {
      urlString = 'https://api.whatsapp.com/send?phone=$telefonoLimpio';
    } else {
      final String encodedMessage = Uri.encodeQueryComponent(message);
      urlString = 'https://api.whatsapp.com/send?phone=$telefonoLimpio&text=$encodedMessage';
    }

    final Uri whatsappUrl = Uri.parse(urlString);

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'No se pudo abrir WhatsApp. Asegúrate de que la aplicación esté instalada y el número sea válido.';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir WhatsApp: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _processAndSendMessage(String plantillaContenido) {
    String mensajeFinal = plantillaContenido;
    widget.dataForVariables.forEach((key, value) {
      mensajeFinal = mensajeFinal.replaceAll(key, value);
    });
    _launchWhatsApp(mensajeFinal);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Plantilla>>(
      future: _plantillasFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: const Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return AlertDialog(
            title: const Text('Error'),
            content: const Text('No se pudieron cargar las plantillas.'),
          );
        }

        final plantillasDisponibles = snapshot.data!.where((p) {
  return p.tipo == widget.tipoPlantilla && 
         !p.nombre.startsWith('@') &&
         p.visibilidad.contains(widget.categoriaDestino); // ✅ FILTRO POR PANTALLA
}).toList();

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AlertDialog(
            title: Center(child: Text(widget.title)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (plantillasDisponibles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No hay plantillas disponibles para este tipo. Ve a Plantillas para crearlas.'),
                    ),
                  ...plantillasDisponibles.map((plantilla) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _processAndSendMessage(plantilla.contenido);
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            alignment: Alignment.centerLeft,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                          child: Text(
                            plantilla.nombre.toUpperCase(),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  if (plantillasDisponibles.isNotEmpty) const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _launchWhatsApp(null);
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          alignment: Alignment.centerLeft,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.chat, color: Colors.black),
                            SizedBox(width: 8),
                            Text('ABRIR CHAT SIN MENSAJE'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            backgroundColor: const Color(0xFF1E1E1E).withOpacity(0.85),
            titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          ),
        );
      },
    );
  }
}