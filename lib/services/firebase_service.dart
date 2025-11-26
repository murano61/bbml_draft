import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  static Future<void> init({FirebaseOptions? options}) async {
    try {
      if (Firebase.apps.isEmpty) {
        if (options != null) {
          await Firebase.initializeApp(options: options);
        } else {
          // Fallback init for platforms with default options available
          await Firebase.initializeApp();
        }
      }
      _initialized = true;
    } catch (e) {
      debugPrint('Firebase init failed: $e');
      _initialized = false;
    }
  }

  static FirebaseFirestore get db => FirebaseFirestore.instance;
}

