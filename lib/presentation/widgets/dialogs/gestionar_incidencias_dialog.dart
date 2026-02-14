import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/providers/incidencia_provider.dart';
import '../../../domain/models/incidencia_model.dart';
import '../../../domain/providers/venta_provider.dart';
import '../../../domain/providers/cuenta_provider.dart';

class DialogoIncidenciasLimpio extends ConsumerStatefulWidget {
  final String? ventaId;
  final String? cuentaId;
  final String titulo;

  const DialogoIncidenciasLimpio({
    super.key, 
    this.ventaId, 
    this.cuentaId, 
    required this.titulo
  });

  @override
  _DialogoIncidenciasLimpioState createState() => _DialogoIncidenciasLimpioState();
}

class _DialogoIncidenciasLimpioState extends ConsumerState<DialogoIncidenciasLimpio> {
  final _descController = TextEditingController();
  
  // Variables de estado (Garantizadas en false)
  bool _quierePausar = false; 
  bool _quiereCascada = false;

  @override
  void initState() {
    super.initState();
    _quierePausar = false;
    _quiereCascada = false;
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  // ✅ Lógica estricta de 24 horas para el mensaje informativo
  String _formatearCompensacion(DateTime inicio) {
    final diferencia = DateTime.now().difference(inicio);
    final diasCompletos = diferencia.inDays; 

    if (diasCompletos < 1) {
      final horas = diferencia.inHours;
      final minutos = diferencia.inMinutes % 60;
      return "Sin compensación de días\n(Duración: ${horas}h ${minutos}m)";
    }
    
    return "Se compensarán: $diasCompletos ${diasCompletos == 1 ? 'día' : 'días'} completos";
  }

  @override
  Widget build(BuildContext context) {
    final idCombo = widget.ventaId != null ? "venta:${widget.ventaId}" : "cuenta:${widget.cuentaId}";
    final incidenciasAsync = ref.watch(incidenciasFamily(idCombo));

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Row(
        children: [
          const Icon(Icons.history_edu, color: Colors.amber, size: 24),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.titulo, style: const TextStyle(color: Colors.white, fontSize: 18))),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("FALLOS ACTIVOS", 
                style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 10),
              
              incidenciasAsync.when(
                data: (lista) => lista.isEmpty 
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: Text("No hay fallos activos", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))),
                    )
                  : Column(
                      children: lista.map((inc) => Card(
                        color: Colors.black26,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8), 
                          side: BorderSide(color: inc.congelarTiempo ? Colors.amber.withOpacity(0.3) : Colors.transparent)
                        ),
                        child: ListTile(
                          leading: Icon(
                            inc.congelarTiempo ? Icons.pause_circle_filled : Icons.info_outline, 
                            color: inc.congelarTiempo ? Colors.amber : Colors.blue
                          ),
                          title: Text(inc.descripcion, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                          subtitle: Text("Reportado: ${DateFormat('dd/MM HH:mm').format(inc.creadoAt.toLocal())}", 
                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: inc.congelarTiempo ? Colors.green.withOpacity(0.8) : Colors.blueGrey, 
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              if (inc.congelarTiempo) {
                                _confirmarResolucionConDias(inc, idCombo);
                              } else {
                                _resolverAccion(inc.id, idCombo);
                              }
                            },
                            child: const Text("RESOLVER", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      )).toList(),
                    ),
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                error: (e, _) => Text("Error: $e", style: const TextStyle(color: Colors.red)),
              ),
              
              const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(color: Colors.white10)),

              const Text("REGISTRAR NUEVO FALLO", 
                style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 10),
              
              TextField(
                controller: _descController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Escriba los detalles del problema...",
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                  filled: true,
                  fillColor: Colors.black12,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              
              const SizedBox(height: 10),
              
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Congelar tiempo (Pausar)", style: TextStyle(color: Colors.white, fontSize: 13)),
                value: _quierePausar,
                activeColor: Colors.amber,
                onChanged: (v) => setState(() => _quierePausar = v),
              ),
              
              if (widget.cuentaId != null)
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.05), 
                    borderRadius: BorderRadius.circular(8), 
                    border: Border.all(color: Colors.amber.withOpacity(0.1))
                  ),
                  child: CheckboxListTile(
                    title: const Text("Efecto Cascada", style: TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text("Pausar todos los perfiles vinculados", style: TextStyle(color: Colors.amber, fontSize: 11)),
                    value: _quiereCascada,
                    activeColor: Colors.amber,
                    checkColor: Colors.black,
                    onChanged: (v) => setState(() => _quiereCascada = v!),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), 
          child: const Text("CERRAR", style: TextStyle(color: Colors.grey))
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
          ),
          icon: const Icon(Icons.save),
          onPressed: _registrarNuevoFallo,
          label: const Text("REGISTRAR FALLO", style: TextStyle(fontWeight: FontWeight.bold)),
        )
      ],
    );
  }

  Future<void> _registrarNuevoFallo() async {
    if (_descController.text.isEmpty) return;
    final idCombo = widget.ventaId != null ? "venta:${widget.ventaId}" : "cuenta:${widget.cuentaId}";
    
    await ref.read(incidenciasFamily(idCombo).notifier).crearIncidencia(
      _descController.text, 
      _quierePausar, 
      _quiereCascada
    );
    
    _descController.clear();
    Navigator.pop(context); // Cierre preventivo para limpiar caché
    ref.invalidate(ventasProvider);
    ref.invalidate(cuentasProvider);
  }

  Future<void> _resolverAccion(String id, String idCombo) async {
    await ref.read(incidenciasFamily(idCombo).notifier).resolverIncidencia(id);
    ref.invalidate(ventasProvider);
    ref.invalidate(cuentasProvider);
  }

  Future<void> _confirmarResolucionConDias(Incidencia inc, String idCombo) async {
    final mensajeCompensacion = _formatearCompensacion(inc.creadoAt);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Confirmar Resolución", 
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 350, 
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Basado en bloques de 24h exactas:", 
                style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.05), 
                  borderRadius: BorderRadius.circular(8), 
                  border: Border.all(color: Colors.green.withOpacity(0.3))
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.green, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        mensajeCompensacion, 
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              const Text("Al aceptar, la fecha de vencimiento se actualizará.", 
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await _resolverAccion(inc.id, idCombo);
            },
            child: const Text("ACEPTAR Y RESOLVER"),
          ),
        ],
      ),
    );
  }
}