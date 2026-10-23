import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_routes.dart';
import '../../app/session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_size.dart';
import '../../theme/app_type.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_input.dart';
import '../auth/data/api_error.dart';
import '../auth/widgets/cta_bar.dart';
import '../city/widgets/leading_icon_header.dart';
import 'data/profile_setup_repository.dart';
import 'photo_picker.dart';

const _nameMaxLength = 50;
// Промежуток 24 макета («Вход - СМС код (неправильный код)» – «Создание профиля - Базовый экран»), в шкале `AppSize` его нет.
const double _gap24 = 24;
const double _photoSize = 96;
const double _photoButtonSize = 24;
const double _photoIconSize = 48;
const double _sourceCardHeight = 96;
const double _sourceIconBox = 48;

/// Создание профиля («Создание профиля - Базовый экран», «Создание профиля - Ввод имя», «Создание профиля - Данные заполнены», «Создание профиля - Загрузка фото»): фото из камеры или галереи, имя (обязательно, FR-02).
/// «Далее» отправляет имя, фото, выбранные до входа город и роль одним `PATCH /me`.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, this.pickPhoto = pickPhotoFromDevice});

  final PhotoPicker pickPhoto;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _name = TextEditingController();
  final _nameFocus = FocusNode();
  File? _photo;
  String? _photoId;
  bool _uploading = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _showError(Object error) {
    final l10n = AppLocalizations.of(context);
    final text = isCameraDenied(error) ? l10n.photoCameraDenied : switch (apiErrorCode(error)) {
      'file_too_large' => l10n.profileSetupErrorFileTooLarge,
      'file_type' => l10n.profileSetupErrorFileType,
      _ => l10n.profileSetupErrorGeneric,
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _choosePhoto() async {
    final l10n = AppLocalizations.of(context);
    final repository = ProfileSetupRepository(AppSession.of(context).api);
    final source = await AppBottomSheet.show<PhotoSource>(
      context,
      title: l10n.profileSetupPhotoTitle,
      child: const _SourceChoice(),
    );
    if (source == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final file = await widget.pickPhoto(source);
      if (file == null) return;
      final uploaded = await repository.uploadPhoto(file);
      if (!mounted) return;
      setState(() {
        _photo = file;
        _photoId = uploaded.id;
      });
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    final session = AppSession.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await ProfileSetupRepository(session.api).save(
        name: _name.text.trim(),
        photoFileId: _photoId,
        cityId: session.pendingCityId,
        mode: session.pendingMode,
      );
      await session.refresh();
      session
        ..pendingCityId = null
        ..pendingMode = null;
      navigator.pushNamedAndRemoveUntil(AppRoutes.shell, (_) => false);
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: Column(
        children: [
          LeadingIconHeader(title: l10n.profileSetupTitle),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSize.pad16),
              child: Column(
                children: [
                  Text(l10n.profileSetupHint, style: AppType.body2.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: _gap24),
                  _PhotoPicker(photo: _photo, busy: _uploading, onTap: _uploading ? null : _choosePhoto),
                  const SizedBox(height: _gap24),
                  ListenableBuilder(
                    listenable: _name,
                    builder: (context, _) => AppInput(
                      label: l10n.profileSetupName,
                      controller: _name,
                      focusNode: _nameFocus,
                      maxLength: _nameMaxLength,
                      textCapitalization: TextCapitalization.words,
                      suffix: Text(
                        '${_name.text.length}/$_nameMaxLength',
                        style: AppType.bodyCaption1.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ListenableBuilder(
            listenable: _name,
            builder: (context, _) => CtaBar(
              children: [
                CtaButton(
                  // всегда «Далее»; «Начать» кадров «Создание профиля - Ввод имя», «Создание профиля - Загрузка фото» снято (реестр отступлений).
                  label: l10n.profileSetupNext,
                  loading: _saving,
                  onPressed: _name.text.trim().isEmpty || _uploading ? null : _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Круглое фото 96 с зелёной кнопкой-карандашом; нажатие открывает шторку выбора источника.
class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({required this.photo, required this.busy, required this.onTap});

  final File? photo;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('profile_setup_photo_button'),
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(
        width: _photoSize,
        height: _photoSize,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipOval(
                child: ColoredBox(
                  color: AppColors.bgControl,
                  child: busy
                      ? const Center(child: CircularProgressIndicator(strokeWidth: AppSize.stroke2, color: AppColors.accentPrimary))
                      : photo == null
                          ? const Center(child: AppIcon('users_user_rounded', size: _photoIconSize, color: AppColors.textSecondary))
                          : Image.file(photo!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: _photoButtonSize,
                height: _photoButtonSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.accentPrimary, borderRadius: BorderRadius.circular(AppSize.radius8)),
                child: const AppIcon('system_pen', size: AppSize.icon12, color: AppColors.textOnAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Две карточки шторки: «Камера» и «Галерея» («Создание профиля - Загрузка фото»).
class _SourceChoice extends StatelessWidget {
  const _SourceChoice();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: _SourceCard(icon: 'media_camera', label: l10n.profileSetupCamera, source: PhotoSource.camera),
        ),
        const SizedBox(width: AppSize.gap8),
        Expanded(
          child: _SourceCard(icon: 'media_gallery_wide', label: l10n.profileSetupGallery, source: PhotoSource.gallery),
        ),
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.icon, required this.label, required this.source});

  final String icon;
  final String label;
  final PhotoSource source;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSize.radius12));
    return Material(
      color: AppColors.bgSurface,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: () => Navigator.of(context).pop(source),
        child: Container(
          height: _sourceCardHeight,
          padding: const EdgeInsets.all(AppSize.pad12),
          child: Column(
            children: [
              Container(
                width: _sourceIconBox,
                height: _sourceIconBox,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.accentPrimary, borderRadius: BorderRadius.circular(AppSize.radius8)),
                child: AppIcon(icon, size: AppSize.icon24, color: AppColors.textOnAccent),
              ),
              const SizedBox(height: AppSize.gap4),
              Text(label, style: AppType.body2.copyWith(color: AppColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}
