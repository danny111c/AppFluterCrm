import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'overlay_notification.dart';
import '../../../domain/models/tipo_cuenta_model.dart';

class NotificationService {
  // --- CONFIGURACIÓN DE TIEMPOS ---
  static const Duration _duracionCorta = Duration(seconds: 2);
  static const Duration _duracionLarga = Duration(seconds: 3);

  // --- MÉTODOS BASE (CONECTAN CON EL OVERLAY ANIMADO) ---
  static void showSuccess(BuildContext context, String message) {
    OverlayNotification.show(
      context: context,
      message: message,
      type: NotificationType.success,
      duration: _duracionCorta,
    );
  }

  static void showError(BuildContext context, String message) {
    OverlayNotification.show(
      context: context,
      message: message,
      type: NotificationType.error,
      duration: _duracionLarga,
    );
  }

  static void showWarning(BuildContext context, String message) {
    OverlayNotification.show(
      context: context,
      message: message,
      type: NotificationType.warning,
      duration: _duracionCorta,
    );
  }

  static void showInfo(BuildContext context, String message) {
    OverlayNotification.show(
      context: context,
      message: message,
      type: NotificationType.info,
      duration: _duracionCorta,
    );
  }

  static void showDeleted(BuildContext context, String itemType) {
    OverlayNotification.show(
      context: context,
      message: '$itemType eliminado',
      type: NotificationType.deleted,
      duration: _duracionCorta,
    );
  }

  // --- MÉTODOS DE CONVENIENCIA (CRUD) ---
  static void showAdded(BuildContext context, String itemType) {
    showSuccess(context, '$itemType agregada');
  }

  static void showUpdated(BuildContext context, String itemType) {
    showSuccess(context, '$itemType actualizado');
  }

  static void showRenewed(BuildContext context, String itemType) {
    showSuccess(context, '$itemType renovado');
  }

  static void showSaved(BuildContext context, String itemType) {
    showSuccess(context, '$itemType guardado');
  }

  // --- LÓGICA DE PERSONALIZACIÓN (PLATAFORMA Y CUENTAS) ---
  static void showCustomSuccess(BuildContext context, String message, {TipoCuenta? accountType}) {
    final platform = _getCurrentPlatform();
    String prefix = _getPlatformPrefix(platform);
    String customMessage = '$prefix $message';
    
    if (accountType != null) {
      customMessage = '${accountType.nombre}: $customMessage';
    }
    
    showSuccess(context, customMessage);
  }

  static void showCustomError(BuildContext context, String message, {TipoCuenta? accountType}) {
    final platform = _getCurrentPlatform();
    String prefix = _getPlatformPrefix(platform, isError: true);
    String customMessage = '$prefix $message';
    
    if (accountType != null) {
      customMessage = '${accountType.nombre}: $customMessage';
    }
    
    showError(context, customMessage);
  }

  static void showCustomWarning(BuildContext context, String message, {TipoCuenta? accountType}) {
    final platform = _getCurrentPlatform();
    String customMessage = '⚠️ $message';
    if (accountType != null) customMessage = '${accountType.nombre}: $customMessage';
    showWarning(context, customMessage);
  }

  static void showCustomInfo(BuildContext context, String message, {TipoCuenta? accountType}) {
    final platform = _getCurrentPlatform();
    String customMessage = 'ℹ️ $message';
    if (accountType != null) customMessage = '${accountType.nombre}: $customMessage';
    showInfo(context, customMessage);
  }

  // --- DETECCIÓN DE PLATAFORMA ---
  static String _getCurrentPlatform() {
    if (kIsWeb) return 'Web';
    try {
      if (Platform.isAndroid) return 'Android';
      if (Platform.isIOS) return 'iOS';
      if (Platform.isWindows) return 'Windows';
    } catch (e) {
      return 'PC';
    }
    return 'PC';
  }

  static String _getPlatformPrefix(String platform, {bool isError = false}) {
    if (isError) {
      switch (platform) {
        case 'Android': return '📱❌';
        case 'iOS': return '🍎❌';
        case 'Web': return '🌐❌';
        default: return '❌';
      }
    }
    switch (platform) {
      case 'Android': return '📱';
      case 'iOS': return '🍎';
      case 'Web': return '🌐';
      default: return '✨';
    }
  }

  // --- MÉTODOS ESPECÍFICOS DE CUENTA ---
  static void showAccountAdded(BuildContext context, TipoCuenta accountType) {
    showCustomSuccess(context, 'Cuenta agregada exitosamente', accountType: accountType);
  }

  static void showAccountUpdated(BuildContext context, TipoCuenta accountType) {
    showCustomSuccess(context, 'Cuenta actualizada exitosamente', accountType: accountType);
  }

  static void showAccountDeleted(BuildContext context, TipoCuenta accountType) {
    showDeleted(context, accountType.nombre);
  }

  static void showAccountError(BuildContext context, String error, TipoCuenta accountType) {
    showCustomError(context, error, accountType: accountType);
  }

  static void showPlatformInfo(BuildContext context, String message) {
    final platform = _getCurrentPlatform();
    showCustomInfo(context, 'Plataforma $platform: $message');
  }
}