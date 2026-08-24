/// cloud_repo.dart — абстракция облачного хранилища снапшота (Model/репозиторий).
///
/// За что отвечает файл:
///   Прячет `cloud_firestore` за узким интерфейсом [CloudRepo] (fetch/save
///   документа `users/{uid}`), чтобы [SyncController] не зависел напрямую от
///   Firebase и был юнит-тестируемым с фейковым репозиторием. Firestore-
///   реализация [FirestoreCloudRepo] — ЕДИНСТВЕННОЕ место с прямым доступом к
///   `FirebaseFirestore.instance`. Провайдер [cloudRepoProvider] переопределяется
///   в тестах и (при желании) для локальных/офлайн-режимов.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Узкий интерфейс облачного хранилища снапшота прогресса.
abstract interface class CloudRepo {
  /// Доступно ли облако прямо сейчас (Firebase инициализирован).
  bool get available;

  /// Читает документ `users/[uid]`; `null` — документа ещё нет.
  Future<Map<String, dynamic>?> fetch(String uid);

  /// Пишет документ `users/[uid]` со слиянием (merge).
  Future<void> save(String uid, Map<String, dynamic> data);
}

/// Реализация поверх Cloud Firestore — единственная точка с `cloud_firestore`.
/// Доступ к `FirebaseFirestore.instance` ленивый (внутри методов), чтобы само
/// создание объекта не требовало инициализированного Firebase.
class FirestoreCloudRepo implements CloudRepo {
  /// Создаёт репозиторий Firestore.
  const FirestoreCloudRepo();

  @override
  bool get available => Firebase.apps.isNotEmpty;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  @override
  Future<Map<String, dynamic>?> fetch(String uid) async =>
      (await _doc(uid).get()).data();

  @override
  Future<void> save(String uid, Map<String, dynamic> data) =>
      _doc(uid).set(data, SetOptions(merge: true));
}

/// Провайдер облачного репозитория. По умолчанию — Firestore; в тестах
/// переопределяется фейком через `overrideWithValue`.
final cloudRepoProvider = Provider<CloudRepo>(
  (_) => const FirestoreCloudRepo(),
);
