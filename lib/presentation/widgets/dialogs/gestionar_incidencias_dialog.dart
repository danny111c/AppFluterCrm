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

  const DialogoIncidenciasLimpio({super.key, this.ventaId, this.cuentaId, required this.titulo});

  @override
  _DialogoIncidenciasLimpioState createState() => _DialogoIncidenciasLimpioState();
}

class _DialogoIncidenciasLimpioState extends ConsumerState<DialogoIncidenciasLimpio> {
  
  String _obtenerTiempoTranscurrido(DateTime inicio) {
    final diff = DateTime.now().difference(inicio);
    final d = diff.inDays;
    final h = diff.inHours % 24;
    final m = diff.inMinutes % 60;
    return "$d días, $h horas y $m min";
  }

  @override
  Widget build(BuildContext context) {
    final idCombo = widget.ventaId != null ? "venta:${widget.ventaId}" : "cuenta:${widget.cuentaId}";
    final incidenciasAsync = ref.watch(incidenciasFamily(idCombo));

    return AlertDialog(
      backgroundColor: const Color(0xFF181818),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              widget.titulo, 
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
            )
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.amber, size: 28),
            onPressed: () => _abrirModalRegistro(context, idCombo),
          )
        ],
      ),
      content: SizedBox(
        width: 550,
        child: incidenciasAsync.when(
          data: (lista) {
            // SEPARACIÓN DE LISTAS
            final pausas = lista.where((i) => i.congelarTiempo).toList();
            final notas = lista.where((i) => !i.congelarTiempo).toList();

            if (lista.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40), 
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inbox, color: Colors.grey, size: 40),
                    SizedBox(height: 10),
                    Text("No hay incidencias registradas", style: TextStyle(color: Colors.grey)),
                  ],
                )
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- SECCIÓN 1: FALLOS CON PAUSA (ACTIVOS) ---
                        if (pausas.isNotEmpty) ...[
                          _sectionHeader("SOPORTE ACTIVO (CON PAUSA)", Colors.amber, Icons.pause_circle_filled),
                          const SizedBox(height: 5),
                          ...pausas.map((inc) => _buildCardIncidencia(inc, idCombo, esPausa: true)),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber, 
                              foregroundColor: Colors.black, 
                              minimumSize: const Size(double.infinity, 45),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                            ),
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text("FINALIZAR SOPORTE Y COMPENSAR", style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () => _mostrarResumenCompensacion(pausas, idCombo),
                          ),
                          const Divider(color: Colors.white10, height: 40, thickness: 1),
                        ],

                        // --- SECCIÓN 2: FALLOS SIN PAUSA (NOTAS) ---
                        if (notas.isNotEmpty) ...[
                          _sectionHeader("NOTAS E INCIDENCIAS (SIN PAUSA)", Colors.blueGrey.shade300, Icons.note_alt),
                          const SizedBox(height: 5),
                          ...notas.map((inc) => _buildCardIncidencia(inc, idCombo, esPausa: false)),
                        ],
                        
                        if (pausas.isEmpty && notas.isEmpty)
                          const Center(child: Text("Sin registros", style: TextStyle(color: Colors.grey))),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: Colors.amber)),
          error: (e, _) => Text("Error: $e", style: const TextStyle(color: Colors.red)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), 
          child: const Text("CERRAR", style: TextStyle(color: Colors.grey))
        ),
      ],
    );
  }

  Widget _sectionHeader(String titulo, Color color, IconData icono) {
    return Row(
      children: [
        Icon(icono, color: color, size: 16),
        const SizedBox(width: 8),
        Text(
          titulo, 
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)
        ),
      ],
    );
  }

  Widget _buildCardIncidencia(Incidencia inc, String idCombo, {required bool esPausa}) {
    return Card(
      color: esPausa ? Colors.amber.withOpacity(0.08) : Colors.white.withOpacity(0.03),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: esPausa ? Colors.amber.withOpacity(0.2) : Colors.transparent)
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          esPausa ? Icons.timer : Icons.chat_bubble_outline, 
          color: esPausa ? Colors.amber : Colors.grey, 
          size: 18
        ),
        title: Text(
          inc.descripcion, 
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)
        ),
        subtitle: Text(
          "${DateFormat('dd/MM HH:mm').format(inc.creadoAt.toLocal())} • PRIORIDAD: ${inc.prioridad.toUpperCase()}", 
          style: const TextStyle(fontSize: 10, color: Colors.grey)
        ),
        trailing: esPausa 
          ? const Icon(Icons.hourglass_bottom, color: Colors.amber, size: 16)
          : IconButton(
              icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
              tooltip: "Marcar como resuelto",
              onPressed: () async {
                await ref.read(incidenciasFamily(idCombo).notifier).resolverIncidencia(inc.id, 0, 0);
                ref.invalidate(ventasProvider);
                ref.invalidate(cuentasProvider);
              },
            ),
      ),
    );
  }

  void _abrirModalRegistro(BuildContext context, String idCombo) {
    showDialog(
      context: context,
      builder: (context) => _FormularioRegistroFallo(
        ventaId: widget.ventaId,
        cuentaId: widget.cuentaId,
        idCombo: idCombo,
        listaActual: ref.read(incidenciasFamily(idCombo)).value ?? [],
      ),
    );
  }

  void _mostrarResumenCompensacion(List<Incidencia> grupo, String idCombo) {
    final ahora = DateTime.now();
    final inicioPausa = grupo.map((i) => i.creadoAt).reduce((a, b) => a.isBefore(b) ? a : b);
    final reportesCascada = grupo.where((i) => i.huboCascada).toList();
    
    int diasP = ahora.difference(inicioPausa).inDays;
    int diasC = 0;
    if (reportesCascada.isNotEmpty) {
      final inicioC = reportesCascada.map((i) => i.creadoAt).reduce((a, b) => a.isBefore(b) ? a : b);
      diasC = ahora.difference(inicioC).inDays;
    }

    final pCtrl = TextEditingController(text: diasP.toString());
    final cCtrl = TextEditingController(text: diasC.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        title: const Text("Resumen de Soporte", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _rowResumen("Días Cuenta:", pCtrl, "Duración: ${_obtenerTiempoTranscurrido(inicioPausa)}"),
            if (reportesCascada.isNotEmpty) ...[
              const SizedBox(height: 15),
              _rowResumen("Días Clientes (Cascada):", cCtrl, "Duración: ${_obtenerTiempoTranscurrido(reportesCascada.first.creadoAt)}"),
            ]
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              await ref.read(incidenciasFamily(idCombo).notifier).resolverGrupoSoporteMasivo(
                id: widget.cuentaId ?? widget.ventaId!,
                esCuenta: widget.cuentaId != null,
                diasP: int.tryParse(pCtrl.text) ?? 0,
                diasC: int.tryParse(cCtrl.text) ?? 0,
              );
              Navigator.pop(ctx);
              Navigator.pop(context);
              ref.invalidate(ventasProvider);
              ref.invalidate(cuentasProvider);
            }, 
            child: const Text("ACEPTAR"),
          ),
        ],
      ),
    );
  }

  Widget _rowResumen(String label, TextEditingController ctrl, String sub) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      Text(sub, style: const TextStyle(color: Colors.amber, fontSize: 11, fontStyle: FontStyle.italic)),
      const SizedBox(height: 8),
      TextField(controller: ctrl, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold), decoration: const InputDecoration(filled: true, fillColor: Colors.black26, border: OutlineInputBorder())),
    ]);
  }
}

// -----------------------------------------------------------------------------
// FORMULARIO DE REGISTRO (CON LA LÓGICA DE LIBERTAD QUE PEDISTE)
// -----------------------------------------------------------------------------
class _FormularioRegistroFallo extends ConsumerStatefulWidget {
  final String? ventaId;
  final String? cuentaId;
  final String idCombo;
  final List<Incidencia> listaActual;

  const _FormularioRegistroFallo({required this.ventaId, required this.cuentaId, required this.idCombo, required this.listaActual});

  @override
  _FormularioRegistroFalloState createState() => _FormularioRegistroFalloState();
}

class _FormularioRegistroFalloState extends ConsumerState<_FormularioRegistroFallo> {
  final _controller = TextEditingController();
  String _prioridad = 'media';
  bool _pausar = false;
  bool _cascada = false;

  @override
  Widget build(BuildContext context) {
    // Detectamos si la cascada ya está activa en la base de datos
    final bool hayCascadaActiva = widget.listaActual.any((i) => i.huboCascada);
    // Detectamos si la pausa simple ya está activa en la base de datos
    final bool hayPausaActiva = widget.listaActual.any((i) => i.congelarTiempo);

    return AlertDialog(
      backgroundColor: const Color(0xFF222222),
      title: const Text("Registrar Nuevo Fallo", style: TextStyle(color: Colors.white, fontSize: 16)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _prioridad,
              dropdownColor: const Color(0xFF333333),
              decoration: const InputDecoration(labelText: "Prioridad", labelStyle: TextStyle(color: Colors.amber, fontSize: 12)),
               // 2. ACTUALIZAMOS LA LISTA AQUÍ (Solo 3 opciones)
              items: ['baja', 'media', 'alta'].map((p) => DropdownMenuItem(
                value: p, 
                child: Text(p.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12))
              )).toList(),
              onChanged: (v) => setState(() => _prioridad = v!),
            ),
            const SizedBox(height: 15),
            TextField(controller: _controller, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Descripción...", hintStyle: TextStyle(color: Colors.grey)), maxLines: 3),
            const SizedBox(height: 10),

            // ✅ LÓGICA DE CHECKS CORREGIDA: LIBERTAD TOTAL
            
            // 1. Si NO hay cascada activa, el usuario puede elegir
            if (!hayCascadaActiva) ...[
              
              // Solo mostramos el Switch de pausa si la cuenta no está ya pausada
              if (!hayPausaActiva)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Congelar tiempo (Pausar)", style: TextStyle(color: Colors.white, fontSize: 13)),
                  value: _pausar,
                  activeColor: Colors.amber,
                  onChanged: (v) => setState(() {
                    _pausar = v;
                    if (!_pausar) _cascada = false; // Si apaga pausa, se apaga cascada
                  }),
                ),

              // El check de cascada siempre disponible (a menos que ya haya una cascada activa)
              if (widget.cuentaId != null)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Efecto Cascada", style: TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold)),
                  value: _cascada,
                  activeColor: Colors.amber,
                  onChanged: (v) => setState(() {
                    _cascada = v!;
                    if (_cascada) _pausar = true; // Si marca cascada, se activa el check de pausa
                  }),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
          onPressed: () async {
            if (_controller.text.isEmpty) return;
            
            // Si el usuario marcó los checks, se envían. 
            // Si no marcó nada (aunque haya pausa activa), se envía false para que sea una NOTA.
            await ref.read(incidenciasFamily(widget.idCombo).notifier).crearIncidencia(
              _controller.text, 
              _pausar, 
              _cascada, 
              _prioridad
            );
            Navigator.pop(context);
            ref.invalidate(ventasProvider);
            ref.invalidate(cuentasProvider);
          },
          child: const Text("GUARDAR"),
        ),
      ],
    );
  }
}