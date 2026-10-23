import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// Откуда взять фото (шторка «Создание профиля - Загрузка фото»).
enum PhotoSource { camera, gallery }

/// Выбор фото; `null` — пользователь передумал. В тестах подменяется.
typedef PhotoPicker = Future<File?> Function(PhotoSource source);

/// пользователь запретил камеру (код `image_picker` на Android) — это не сеть, текст свой.
bool isCameraDenied(Object error) => error is PlatformException && error.code == 'camera_access_denied';

/// Системная камера или галерея Android (`image_picker`).
Future<File?> pickPhotoFromDevice(PhotoSource source) async {
  final picked = await ImagePicker().pickImage(
    source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 1600,
    imageQuality: 85,
  );
  return picked == null ? null : File(picked.path);
}
