import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'venta_provider.dart'; // importa el notifier y el estado

final ventasPorCuentaProvider =
    StateNotifierProvider<VentasNotifier, VentasState>((ref) {
  return VentasNotifier(ref);
});