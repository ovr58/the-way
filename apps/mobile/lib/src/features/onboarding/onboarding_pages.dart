import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_images.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_size.dart';
import '../../theme/app_type.dart';
import '../../widgets/app_icon.dart';
import 'onboarding_images.dart';

// Размеры кадров «Онбординг - Слайд 1» – «Предзагрузка», которых нет в шкале `AppSize`.
const double _cardTop = 32;
const double _paginatorGap = 40;
const double _splashLogo = 299;

// Верх слайдов «Онбординг - Слайд 1» – «Онбординг - Слайд 3» в координатах кадра. Кадр рисует строку iPhone высотой 54 — рамку телефона;
// на устройстве её место занимает системная строка, поэтому всё ниже неё отсчитывается от
// `MediaQuery.paddingOf(context).top`, а зелёный фон заходит под системную строку.
const double _frameStatusBar = 54;
const double _greenTopHeight = 222 - _frameStatusBar; // зелёный верх «Онбординг - Слайд 2», «Онбординг - Слайд 3»: 222 в кадре
const double _greenTopRadius = AppSize.radius24; // нижние углы зелёного верха
const double _greenLogoTop = 60 - _frameStatusBar; // логотип с названием: y 60 в кадре
const double _slideOneTitleTop = 79 - _frameStatusBar; // заголовок «Онбординг - Слайд 1»: y 79
const double _slideOneImageTop = 164 - _frameStatusBar; // картинка «Онбординг - Слайд 1»: y 164, 378×290, по центру
const double _slideOneImageWidth = 378;
const double _slideOneImageHeight = 290;
const double _slideTwoImageTop = 145 - _frameStatusBar; // машина «Онбординг - Слайд 2»: y 145, 375×273 — поверх края зелёного
const double _slideTwoImageHeight = 273;
const double _roleImageTop = 143 - _frameStatusBar; // машина «Онбординг - Слайд 3»: y 143, 375×274
const double _roleImageHeight = 274;
const double _roleCardGap = 9; // зазор карточек роли «Онбординг - Слайд 3» (167 + 9 + 167)
const double _logoSmall = 50;
const double _roleCardIcon = 80;
const double _roleCardHeight = 132;
const double _paginatorWidthActive = 40;
const double _paginatorWidthIdle = 12;
const double _paginatorHeight = 8;

// Цвета кадров «Онбординг - Слайд 2» – «Онбординг - Слайд 3» без токена (значения макета; ближайшие токены другие: F3F3F3, F7F7F8).
const Color _cardStroke = Color(0xFFF6F6F7); // обводка 3 px нижней карточки («Онбординг - Слайд 2», «Онбординг - Слайд 3»)
const Color _roleCardBackground = Color(0xFFEDEDED); // фон карточки выбора роли («Онбординг - Слайд 3»)
const Color _roleCardIdle = Color(0xFFF6F6F6); // невыбранная карточка роли («Онбординг - Слайд 3»)

/// Заставка («Предзагрузка»): зелёный фон, логотип, «Начать» и «Уже есть аккаунт».
class SplashPage extends StatelessWidget {
  const SplashPage({super.key, required this.onStart, required this.onHaveAccount});

  final VoidCallback onStart;
  final VoidCallback onHaveAccount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ColoredBox(
      color: AppColors.accentPrimary,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16, vertical: AppSize.pad16),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(AppImages.logo, width: _splashLogo, height: _splashLogo),
                    const SizedBox(height: AppSize.gap12),
                    Text(l10n.appTitle, style: AppType.titlesLargeTitle.copyWith(color: AppColors.textOnAccent)),
                    const SizedBox(height: AppSize.gap12),
                    Text(
                      l10n.onboardingSplashTagline,
                      textAlign: TextAlign.center,
                      style: AppType.body2.copyWith(color: AppColors.bgControl),
                    ),
                  ],
                ),
              ),
              _SplashButton(label: l10n.onboardingStart, onPressed: onStart, filled: true),
              const SizedBox(height: AppSize.gap12),
              _SplashButton(label: l10n.onboardingHaveAccount, onPressed: onHaveAccount, filled: false),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashButton extends StatelessWidget {
  const _SplashButton({required this.label, required this.onPressed, required this.filled});

  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSize.radius12),
      side: filled ? BorderSide.none : const BorderSide(color: AppColors.textOnAccent, width: AppSize.stroke1),
    );
    return Material(
      color: filled ? AppColors.textOnAccent : Colors.transparent,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onPressed,
        child: Container(
          width: double.infinity,
          height: AppSize.height42,
          alignment: Alignment.center,
          child: Text(label, style: AppType.button2.copyWith(color: filled ? AppColors.textPrimary : AppColors.textOnAccent)),
        ),
      ),
    );
  }
}

/// Слайд 1 («Онбординг - Слайд 1»): белый фон, заголовок, картинка и нижняя карточка с «Продолжить».
class SlideOnePage extends StatelessWidget {
  const SlideOnePage({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final top = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: AppColors.bgSurface,
      child: Stack(
        children: [
          Positioned(
            top: top + _slideOneTitleTop,
            left: AppSize.pad16,
            right: AppSize.pad16,
            child: _WelcomeTitle(style: AppType.title2, color: AppColors.textPrimary, center: true),
          ),
          // картинка по центру экрана при любой ширине (в кадре 375 её x = −2 — это и есть центр для 378).
          Positioned(
            top: top + _slideOneImageTop,
            left: 0,
            right: 0,
            height: _slideOneImageHeight,
            child: OverflowBox(
              minWidth: _slideOneImageWidth,
              maxWidth: _slideOneImageWidth,
              child: Image.asset(OnboardingImages.slide1, width: _slideOneImageWidth, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _Card(
              color: AppColors.bgSurface,
              textGap: _paginatorGap,
              header: const [],
              text: Text(
                l10n.onboardingSlide1Text,
                textAlign: TextAlign.center,
                style: AppType.title2.copyWith(color: AppColors.textPrimary),
              ),
              page: 0,
              footer: _ContinueButton(label: l10n.onboardingContinue, onPressed: onContinue),
            ),
          ),
        ],
      ),
    );
  }
}

/// Слайд 2 («Онбординг - Слайд 2»): зелёная шапка с логотипом, картинка и тёмная карточка.
class SlideTwoPage extends StatelessWidget {
  const SlideTwoPage({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _GreenTopSlide(
      imageTop: _slideTwoImageTop,
      imageHeight: _slideTwoImageHeight,
      card: _Card(
        color: AppColors.textPrimary,
        stroked: true,
        textGap: AppSize.gap8,
        header: [_WelcomeTitle(style: AppType.title1, color: AppColors.textOnAccent, center: true)],
        text: Text(
          l10n.onboardingSlide2Text,
          textAlign: TextAlign.center,
          style: AppType.title2.copyWith(color: AppColors.textOnAccent),
        ),
        page: 1,
        footer: _ContinueButton(label: l10n.onboardingContinue, onPressed: onContinue),
      ),
    );
  }
}

/// Слайд 3 («Онбординг - Слайд 3»): выбор роли — две карточки, без пагинатора и без кнопки.
class RolePage extends StatefulWidget {
  const RolePage({super.key, required this.initial, required this.onPick});

  /// Карточка, подсвеченная зелёным до выбора (в кадре — «Водитель»).
  final UserMode initial;
  final ValueChanged<UserMode> onPick;

  @override
  State<RolePage> createState() => _RolePageState();
}

class _RolePageState extends State<RolePage> {
  late UserMode _selected = widget.initial;

  void _pick(UserMode mode) {
    setState(() => _selected = mode);
    widget.onPick(mode);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _GreenTopSlide(
      imageTop: _roleImageTop,
      imageHeight: _roleImageHeight,
      card: _Card(
        color: _roleCardBackground,
        stroked: true,
        textGap: AppSize.gap8,
        header: [_WelcomeTitle(style: AppType.title1, color: AppColors.textPrimary, center: true)],
        text: Text(
          l10n.onboardingRoleQuestion,
          textAlign: TextAlign.center,
          style: AppType.title3.copyWith(fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        ),
        page: null,
        footer: Row(
          children: [
            Expanded(
              child: _RoleCard(
                label: l10n.onboardingRoleDriver,
                image: OnboardingImages.roleDriver,
                selected: _selected == UserMode.driver,
                onTap: () => _pick(UserMode.driver),
              ),
            ),
            const SizedBox(width: _roleCardGap),
            Expanded(
              child: _RoleCard(
                label: l10n.onboardingRolePassenger,
                image: OnboardingImages.rolePassenger,
                selected: _selected == UserMode.passenger,
                onTap: () => _pick(UserMode.passenger),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.label, required this.image, required this.selected, required this.onTap});

  final String label;
  final String image;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSize.radius12));
    return Material(
      color: selected ? AppColors.accentPrimary : _roleCardIdle,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Container(
          height: _roleCardHeight,
          padding: const EdgeInsets.all(AppSize.pad12),
          child: Column(
            children: [
              Container(
                width: _roleCardIcon,
                height: _roleCardIcon,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.bgSurface, shape: BoxShape.circle),
                child: Image.asset(image, fit: BoxFit.contain),
              ),
              const SizedBox(height: AppSize.gap4),
              Text(
                label,
                style: AppType.title3.copyWith(color: selected ? AppColors.bgControl : AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Каркас слайдов 2 и 3: зелёный верх со скруглёнными нижними углами, логотип с названием у
/// верхнего края, машина поверх края зелёного, нижняя карточка.
class _GreenTopSlide extends StatelessWidget {
  const _GreenTopSlide({required this.imageTop, required this.imageHeight, required this.card});

  /// Верх и высота картинки под системной строкой — у «Онбординг - Слайд 2» и «Онбординг - Слайд 3» в кадре разные.
  final double imageTop;
  final double imageHeight;
  final Widget card;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final top = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: AppColors.bgSurface,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: top + _greenTopHeight,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.accentPrimary,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(_greenTopRadius)),
              ),
            ),
          ),
          Positioned(
            top: top + _greenLogoTop,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(AppImages.logo, width: _logoSmall, height: _logoSmall),
                const SizedBox(width: AppSize.gap10),
                Text(l10n.appTitle, style: AppType.title2.copyWith(color: AppColors.bgControl)),
              ],
            ),
          ),
          Positioned(
            top: top + imageTop,
            left: 0,
            right: 0,
            height: imageHeight,
            child: Image.asset(OnboardingImages.slide2, fit: BoxFit.cover),
          ),
          Positioned(bottom: 0, left: 0, right: 0, child: card),
        ],
      ),
    );
  }
}

/// Нижняя карточка слайда: скругление сверху 24, заголовок, текст, пагинатор, нижний блок.
class _Card extends StatelessWidget {
  const _Card({
    required this.color,
    this.stroked = false,
    required this.textGap,
    required this.header,
    required this.text,
    required this.page,
    required this.footer,
  });

  final Color color;

  /// Обводка 3 px поверх карточки («Онбординг - Слайд 2», «Онбординг - Слайд 3»); раскладку не сдвигает.
  final bool stroked;
  final double textGap;
  final List<Widget> header;
  final Widget text;

  /// Номер активной точки пагинатора; `null` — пагинатора нет.
  final int? page;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.vertical(top: Radius.circular(AppSize.radius24));
    return Container(
      decoration: BoxDecoration(color: color, borderRadius: radius),
      foregroundDecoration: stroked
          ? BoxDecoration(
              border: Border.all(color: _cardStroke, width: AppSize.stroke3),
              borderRadius: radius,
            )
          : null,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSize.pad16, _cardTop, AppSize.pad16, AppSize.pad16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            // Растяжение по ширине: текст в кадре по центру строки 343, пагинатор — у левого края.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final widget in header) ...[widget, const SizedBox(height: AppSize.gap8)],
              text,
              if (page != null) ...[SizedBox(height: textGap), _Paginator(active: page!)],
              // Нижний отступ блока текста 16 + верхний отступ блока действий 16.
              const SizedBox(height: AppSize.pad16 + AppSize.pad16),
              footer,
            ],
          ),
        ),
      ),
    );
  }
}

class _Paginator extends StatelessWidget {
  const _Paginator({required this.active});

  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 2; i++) ...[
          if (i > 0) const SizedBox(width: AppSize.gap4),
          Container(
            width: i == active ? _paginatorWidthActive : _paginatorWidthIdle,
            height: _paginatorHeight,
            decoration: BoxDecoration(
              color: i == active ? AppColors.accentPrimary : AppColors.borderDefault.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppSize.radius12),
            ),
          ),
        ],
      ],
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSize.radius12));
    return Material(
      color: AppColors.accentPrimary,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onPressed,
        child: Container(
          width: double.infinity,
          height: AppSize.height42,
          padding: const EdgeInsets.symmetric(horizontal: AppSize.pad16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppType.button2.copyWith(color: AppColors.textOnAccent)),
              const AppIcon('arrows_alt_arrow_right', size: AppSize.icon14, color: AppColors.textOnAccent),
            ],
          ),
        ),
      ),
    );
  }
}

/// «Добро пожаловать в Путь», «Путь» — зелёным.
class _WelcomeTitle extends StatelessWidget {
  const _WelcomeTitle({required this.style, required this.color, this.center = false});

  final TextStyle style;
  final Color color;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Text.rich(
      TextSpan(
        style: style.copyWith(color: color),
        children: [
          TextSpan(text: l10n.onboardingWelcomeTitle),
          TextSpan(text: l10n.appTitle, style: const TextStyle(color: AppColors.accentPrimary)),
        ],
      ),
      textAlign: center ? TextAlign.center : TextAlign.start,
    );
  }
}
