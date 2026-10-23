import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app/session.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_size.dart';
import '../../../theme/app_type.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../widgets/app_header.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/app_input.dart';
import '../../../widgets/avatar.dart';
import '../../auth/data/api_error.dart';
import '../../auth/data/phone_format.dart';
import '../../auth/widgets/cta_bar.dart';
import '../../profile_setup/photo_picker.dart';
import '../data/profile_repository.dart';

const _nameMaxLength = 50;
const double _photoSize = 96;
const double _photoButtonSize = 24;
const double _sourceCardHeight = 96;
const double _sourceIconBox = 48;

/// Личные данные («Профиль - Личные данные»): фото и имя правятся, номер только показывается. «Сохранить» активна,
/// когда имя не пусто и что-то изменилось; `PATCH /me` шлёт изменённые поля, остальные `null`.
class PersonalDataScreen extends StatefulWidget {
  const PersonalDataScreen({super.key, this.pickPhoto = pickPhotoFromDevice});

  final PhotoPicker pickPhoto;

  @override
  State<PersonalDataScreen> createState() => _PersonalDataScreenState();
}

class _PersonalDataScreenState extends State<PersonalDataScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String _initialName = '';
  bool _filled = false;
  File? _photo;
  String? _photoId;
  bool _uploading = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filled) return;
    _filled = true;
    final me = AppSession.of(context).me;
    _initialName = me?.name ?? '';
    _name.text = _initialName;
    _phone.text = formatPhone(me?.phone ?? ''); // только показ: в PATCH /me номер не уходит
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _nameChanged => _name.text.trim() != _initialName;
  bool get _canSave => _name.text.trim().isNotEmpty && (_nameChanged || _photoId != null) && !_uploading && !_saving;

  void _showError(Object error, {bool saving = false}) {
    final l10n = AppLocalizations.of(context);
    final text = isCameraDenied(error) ? l10n.photoCameraDenied : switch (apiErrorCode(error)) {
      'file_too_large' when !saving => l10n.profileSetupErrorFileTooLarge,
      'file_type' when !saving => l10n.profileSetupErrorFileType,
      _ => l10n.profileErrorGeneric,
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _choosePhoto() async {
    final l10n = AppLocalizations.of(context);
    final repository = ProfileRepository(AppSession.of(context).api);
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
    final messenger = ScaffoldMessenger.of(context);
    final saved = AppLocalizations.of(context).profileSaved;
    setState(() => _saving = true);
    try {
      await ProfileRepository(session.api).updateProfile(
        name: _nameChanged ? _name.text.trim() : null,
        photoFileId: _photoId,
      );
      await session.refresh();
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(saved)));
    } catch (error) {
      if (mounted) {
        _showError(error, saving: true);
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = AppSession.of(context).me;
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: Column(
        children: [
          AppHeader(title: l10n.profilePersonalData, onBack: () => Navigator.of(context).maybePop()),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSize.pad16),
              child: Column(
                children: [
                  _PhotoButton(url: me?.photoUrl, photo: _photo, busy: _uploading, onTap: _uploading ? null : _choosePhoto),
                  const SizedBox(height: AppSize.gap20),
                  ListenableBuilder(
                    listenable: _name,
                    builder: (context, _) => AppInput(
                      label: l10n.profileSetupName,
                      controller: _name,
                      maxLength: _nameMaxLength,
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                  const SizedBox(height: AppSize.gap8),
                  AppInput(
                    label: l10n.profilePhoneLabel,
                    controller: _phone,
                    readOnly: true,
                    suffix: const AppIcon('system_phone_rounded', size: AppSize.icon18, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          ListenableBuilder(
            listenable: _name,
            builder: (context, _) => CtaBar(
              children: [CtaButton(label: l10n.profileSave, loading: _saving, onPressed: _canSave ? _save : null)],
            ),
          ),
        ],
      ),
    );
  }
}

/// Круглое фото 96 с зелёной кнопкой-карандашом; нажатие открывает шторку выбора источника.
class _PhotoButton extends StatelessWidget {
  const _PhotoButton({required this.url, required this.photo, required this.busy, required this.onTap});

  final String? url;
  final File? photo;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('personal_data_photo'),
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(
        width: _photoSize,
        height: _photoSize,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipOval(
                child: busy
                    ? const ColoredBox(
                        color: AppColors.bgControl,
                        child: Center(child: CircularProgressIndicator(strokeWidth: AppSize.stroke2, color: AppColors.accentPrimary)),
                      )
                    : photo != null
                        ? Image.file(photo!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink())
                        : Avatar(url: url, size: _photoSize, silhouette: true),
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
        Expanded(child: _SourceCard(icon: 'media_camera', label: l10n.profileSetupCamera, source: PhotoSource.camera)),
        const SizedBox(width: AppSize.gap8),
        Expanded(child: _SourceCard(icon: 'media_gallery_wide', label: l10n.profileSetupGallery, source: PhotoSource.gallery)),
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
