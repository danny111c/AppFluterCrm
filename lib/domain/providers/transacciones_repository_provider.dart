import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proyectofinal/infrastructure/repositories/transacciones_repository.dart';

final transaccionesRepositoryProvider = Provider<TransaccionesRepository>((ref) {
  return TransaccionesRepository();
});
