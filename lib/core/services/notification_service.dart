import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:doraty/core/services/database_service.dart';
import 'package:doraty/core/services/supabase_service.dart';
import 'package:doraty/firebase_options.dart';

// Top-level function for background handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint("Handling a background message: ${message.messageId}");
}

class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging? _firebaseMessaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // 1. Initialize Firebase if not already (usually done in main, but safe to check)
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        debugPrint('Firebase already initialized or failed: $e');
      }

      // Initialize FirebaseMessaging AFTER Firebase is ready
      _firebaseMessaging = FirebaseMessaging.instance;

      // 2. Request Permissions
      NotificationSettings settings = await _firebaseMessaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('User granted permission: ${settings.authorizationStatus}');

      // 3. Setup Local Notifications (for foreground display on mobile)
      if (!kIsWeb) {
        const AndroidInitializationSettings initializationSettingsAndroid =
            AndroidInitializationSettings('@mipmap/ic_launcher');

        // iOS settings
        const DarwinInitializationSettings initializationSettingsIOS =
            DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

        const InitializationSettings initializationSettings =
            InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

        await _localNotifications.initialize(
          initializationSettings,
          onDidReceiveNotificationResponse: (NotificationResponse details) {
            debugPrint('Notification clicked payload: ${details.payload}');
            // Handle notification tap logic here if needed
          },
        );

        // Create high importance channel for Android
        await _createNotificationChannel();

        // 4. Register Background Handler (Mobile only)
        FirebaseMessaging.onBackgroundMessage(
            _firebaseMessagingBackgroundHandler);
      }

      // 5. Handle Foreground Messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        if (message.notification != null) {
          debugPrint('Message also contained a notification: ${message.notification}');
          
          // Save notification to database
          final userId = SupabaseService.instance.currentUserId;
          if (userId != null) {
            await DatabaseService().saveNotification(
              userId: userId,
              title: message.notification!.title ?? 'إشعار جديد',
              body: message.notification!.body ?? '',
              data: message.data,
              type: message.data['type'],
              category: message.data['category'],
              imageUrl: message.data['image_url'],
              actionUrl:
                  message.data['action_url'] ?? message.data['click_action'],
            );
          }

          if (!kIsWeb) {
            _showLocalNotification(message);
          } else {
            // On web, browser handles notification display
            debugPrint(
                '📱 Web notification received: ${message.notification!.title}');
          }
        }
      });

      // 6. Get Token
      String? token;
      if (kIsWeb) {
        token = await _firebaseMessaging!.getToken(
          vapidKey:
              'BAwflgI9xXrkurTw5b7k1gXp7Y2VPIDdWgLECj4gttuMWTLLhHlC8fLss_YH-AKelslav3776Fu-iKTeWvJM99E',
        );
      } else {
        token = await _firebaseMessaging!.getToken();
      }
      
      debugPrint("FCM Token: $token");
      
      if (token != null) {
        await DatabaseService().updateFcmToken(token);
        // Subscribe to general topic for broadcasting
        await _firebaseMessaging!.subscribeToTopic('all_users');
        debugPrint('🔔 Subscribed to all_users topic');
      }

      // 7. Listen for token refresh
      _firebaseMessaging!.onTokenRefresh.listen((newToken) async {
        debugPrint("🔄 FCM Token Refreshed: $newToken");
        await DatabaseService().updateFcmToken(newToken);
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      description: 'This channel is used for important notifications.', // description
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  void _showLocalNotification(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription: 'This channel is used for important notifications.',
            icon: '@mipmap/ic_launcher',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        payload: jsonEncode(message.data), // Encode payload as JSON string
      );
    }
  }
}
