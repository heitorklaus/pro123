import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../../auth/domain/models/user_model.dart';
import '../../solar_credits/presentation/widgets/solar_credit_due_alert_dialog.dart';

/// Serviço de Push Notifications (Firebase Cloud Messaging) do Mavis / Taos CRM.
///
/// Responsável por:
/// 1. Solicitar permissão ao usuário (Android/iOS/Web).
/// 2. Registrar e manter atualizado o token FCM em `users/{uid}.fcmTokens`.
/// 3. Escutar notificações recebidas em primeiro plano e cliques em notificações
///    (abrindo o popup de vencimento de Créditos Solar com as 3 ações).
class PushNotificationService {
  PushNotificationService._();

  static String? _initializedForUid;
  static StreamSubscription<String>? _tokenRefreshSub;
  static StreamSubscription<RemoteMessage>? _onMessageSub;
  static StreamSubscription<RemoteMessage>? _onMessageOpenedSub;

  static Future<void> initializeForUser({
    required UserModel user,
    required void Function(String? billId) onSolarCreditPushOpened,
    void Function(String title, String body, String? billId)?
        onForegroundSolarCreditPush,
  }) async {
    // Só solicita/registra push para usuários elegíveis (hoje SuperAdmin; futuro Admins GD)
    if (!SolarCreditDueAlertDialog.isUserEligibleForAlerts(user)) return;

    try {
      final messaging = FirebaseMessaging.instance;

      // Solicita permissão de notificação (iOS / Android 13+ / Web)
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[PushNotificationService] Permissão de push negada.');
        return;
      }

      if (_initializedForUid != user.uid) {
        _initializedForUid = user.uid;

        await _tokenRefreshSub?.cancel();
        _tokenRefreshSub = messaging.onTokenRefresh.listen((newToken) {
          _saveTokenToUser(user.uid, newToken);
        });

        await _onMessageOpenedSub?.cancel();
        _onMessageOpenedSub =
            FirebaseMessaging.onMessageOpenedApp.listen((message) {
          _handleNotificationOpen(message, onSolarCreditPushOpened);
        });

        await _onMessageSub?.cancel();
        _onMessageSub = FirebaseMessaging.onMessage.listen((message) {
          final data = message.data;
          if (data['type'] == 'solar_credit_due') {
            final title = message.notification?.title ??
                'Vencimento — Créditos Solar (GD)';
            final body = message.notification?.body ??
                'Há fatura(s) pendente(s) próxima(s) do vencimento.';
            onForegroundSolarCreditPush?.call(
              title,
              body,
              data['billId']?.toString(),
            );
          }
        });

        // Verifica se o app foi aberto a partir de uma notificação quando estava fechado
        final initialMsg = await messaging.getInitialMessage();
        if (initialMsg != null) {
          _handleNotificationOpen(initialMsg, onSolarCreditPushOpened);
        }
      }

      // Obtém e salva o token FCM atual do aparelho
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _saveTokenToUser(user.uid, token);
      }
    } catch (e) {
      // Em ambientes Web sem Service Worker/VAPID ou emulador sem Play Services, não quebra o app
      debugPrint('[PushNotificationService] Aviso ao inicializar FCM: $e');
    }
  }

  static void _handleNotificationOpen(
    RemoteMessage message,
    void Function(String? billId) onSolarCreditPushOpened,
  ) {
    final data = message.data;
    if (data['type'] == 'solar_credit_due') {
      onSolarCreditPushOpened(data['billId']?.toString());
    }
  }

  static Future<void> _saveTokenToUser(String uid, String token) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastFcmPlatform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'lastFcmUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[PushNotificationService] Erro ao salvar token FCM: $e');
    }
  }

  static Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _onMessageSub?.cancel();
    await _onMessageOpenedSub?.cancel();
    _tokenRefreshSub = null;
    _onMessageSub = null;
    _onMessageOpenedSub = null;
    _initializedForUid = null;
  }
}
