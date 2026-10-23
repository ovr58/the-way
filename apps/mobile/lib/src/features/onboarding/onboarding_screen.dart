import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../app/session.dart';
import 'onboarding_pages.dart';

/// Онбординг: заставка («Предзагрузка») → два слайда («Онбординг - Слайд 1», «Онбординг - Слайд 2») → выбор роли («Онбординг - Слайд 3»). Выбор роли сохраняется
/// в сессии (`pendingMode`) и ведёт к выбору города; «Уже есть аккаунт» — сразу ко входу.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  var _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() => _pages.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);

  void _haveAccount() {
    Navigator.of(context).pushNamed(AppRoutes.auth);
  }

  void _pickRole(UserMode mode) {
    AppSession.of(context).pendingMode = mode;
    Navigator.of(context).pushNamed(AppRoutes.citySelect);
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSession.of(context);
    // «Назад» системы листает на предыдущую страницу; приложение закрывает только с заставки.
    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _pages.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      },
      child: Scaffold(
        body: PageView(
          controller: _pages,
          onPageChanged: (page) => setState(() => _page = page),
          children: [
            SplashPage(onStart: _next, onHaveAccount: _haveAccount),
            SlideOnePage(onContinue: _next),
            SlideTwoPage(onContinue: _next),
            RolePage(initial: session.pendingMode ?? UserMode.driver, onPick: _pickRole),
          ],
        ),
      ),
    );
  }
}
