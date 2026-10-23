import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/app/app_routes.dart';
import 'package:the_way/src/features/booking/cancel/cancel_flow.dart';
import 'package:the_way/src/features/system/temp_blocked_screen.dart';

import '../../support/fake_api.dart';

Map<String, Object?> _preview({int count = 0, bool willBlock = false, int? refund}) =>
    {'cancellationsLast30': count, 'willBlock': willBlock, 'refundAmount': refund};

Map<String, Object?> _result({int count = 1, bool blocked = false, bool refund = false}) => {
      'status': 'cancelled',
      'cancellationsLast30': count,
      'blockedUntil': blocked ? '2026-11-21T10:00:00.000Z' : null,
      'refund': refund ? {'amount': 1800, 'days': 3} : null,
    };

class _Run {
  _Run(this.server, this.opened, this.results);

  final FakeServer server;
  final Map<String, List<Object?>> opened;
  final List<bool> results;
}

/// Экран-вход с кнопкой `run`, которая запускает `runBookingCancel` и записывает результат.
Future<_Run> _start(
  WidgetTester tester,
  FakeServer server,
  BookingStatus status, {
  bool fromAnswer = false,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final opened = <String, List<Object?>>{};
  final results = <bool>[];
  await tester.pumpWidget(
    testApp(
      fakeSession(server),
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            key: const Key('run'),
            onPressed: () async =>
                results.add(await runBookingCancel(context, 'b1', status, fromAnswer: fromAnswer)),
            child: const Text('run'),
          ),
        ),
      ),
      opened: opened,
    ),
  );
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('run')));
  await tester.pumpAndSettle();
  return _Run(server, opened, results);
}

FakeServer _server(Map<String, Object?> preview, [Map<String, Object?>? result]) => FakeServer()
  ..on('GET /bookings/b1/cancel-preview', (_) => FakeReply(200, preview))
  ..on('POST /bookings/b1/cancel', (_) => FakeReply(200, result ?? _result()));

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  group('requested', () {
    testWidgets('«Отменить заявку?» без счётчика; отмена → подсказка «Бронь отменена»', (tester) async {
      final run = await _start(tester, _server(_preview()), BookingStatus.requested);

      expect(find.text('Отменить заявку?'), findsOneWidget);
      expect(find.text('Водитель ещё не ответил на заявку. Отмена не повлияет на ваш аккаунт.'), findsOneWidget);
      expect(find.textContaining('/ 2'), findsNothing);
      expect(find.text('Вернуться'), findsOneWidget);

      await _tap(tester, 'Отменить заявку');
      expect(run.server.of('POST /bookings/b1/cancel'), hasLength(1));
      expect(find.text('Бронь отменена'), findsOneWidget);
      expect(run.results, [true]);
    });
  });

  group('awaiting_payment', () {
    testWidgets('из окна «Пришёл ответ» (fromAnswer): текст «Пришёл ответ», строка «Две отмены…», счётчик «0 / 2»', (tester) async {
      final run = await _start(tester, _server(_preview()), BookingStatus.awaitingPayment, fromAnswer: true);

      expect(find.text('Отменить бронирование?'), findsOneWidget);
      expect(find.text('Водитель уже подтвердил вашу заявку. Вы уверены, что хотите отказаться от поездки?'),
          findsOneWidget);
      expect(find.text('Две отмены в течение 30 дней приведут к автоматической блокировке аккаунта на 30 дней.'),
          findsOneWidget);
      expect(find.text('Отмен за 30 дней'), findsOneWidget);
      expect(find.text('0 / 2'), findsOneWidget);
      expect(find.text('Вернуться'), findsOneWidget);

      await _tap(tester, 'Отказаться от заявки');
      expect(run.server.of('POST /bookings/b1/cancel'), hasLength(1));
      expect(find.text('Бронь отменена'), findsOneWidget);
      expect(run.results, [true]);
    });

    testWidgets('с деталей, willBlock = false: окно «Детали поездки - Лимит отмен» «0 / 2», «Да, отменить» → подсказка', (tester) async {
      final run = await _start(tester, _server(_preview()), BookingStatus.awaitingPayment);

      expect(find.text('Отменить бронирование?'), findsOneWidget);
      expect(find.text('0 / 2'), findsOneWidget);
      expect(find.text('Возврат на карту'), findsNothing);
      expect(find.text('Не отменять'), findsOneWidget);

      await _tap(tester, 'Да, отменить');
      expect(run.server.of('POST /bookings/b1/cancel'), hasLength(1));
      expect(find.text('Бронь отменена'), findsOneWidget);
      expect(run.results, [true]);
    });

    testWidgets('«Не отменять»: отмена не вызвана, результат false', (tester) async {
      final run = await _start(tester, _server(_preview(count: 1)), BookingStatus.awaitingPayment);

      expect(find.text('1 / 2'), findsOneWidget);
      await _tap(tester, 'Не отменять');

      expect(run.server.of('POST /bookings/b1/cancel'), isEmpty);
      expect(find.text('Отменить бронирование?'), findsNothing);
      expect(run.results, [false]);
    });

    testWidgets('willBlock = true: «Детали поездки - Лимит отмен» без строк возврата → «Детали поездки - Лимит отмен» → отмена → «Бронь отменена» → «Понятно» → назад', (tester) async {
      final run = await _start(
        tester,
        _server(_preview(count: 1, willBlock: true), _result(count: 2, blocked: true)),
        BookingStatus.awaitingPayment,
      );

      expect(find.text('Отменить бронирование?'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('Возврат на карту'), findsNothing);

      await _tap(tester, 'Да, отменить');
      expect(find.text('Это может повлиять на ваш аккаунт'), findsOneWidget);
      expect(find.text('У вас уже была одна отмена за последние 30 дней'), findsOneWidget);
      expect(run.server.of('POST /bookings/b1/cancel'), isEmpty);

      await _tap(tester, 'Всё равно отменить');
      expect(run.server.of('POST /bookings/b1/cancel'), hasLength(1));
      expect(find.text('Аккаунт временно заблокирован'), findsOneWidget);
      expect(find.textContaining('Бронирование новых поездок'), findsOneWidget);
      expect(run.results, isEmpty);

      await _tap(tester, 'Понятно');
      expect(find.text('Аккаунт временно заблокирован'), findsNothing);
      expect(find.text('Бронь отменена'), findsNothing);
      expect(run.results, [true]);
    });
  });

  group('paid', () {
    testWidgets('willBlock = false: «Детали поездки - Отмена брони» с возвратом, после отмены экран «Бронь отменена» с 1\u00A0800 ₽', (tester) async {
      final run = await _start(
        tester,
        _server(_preview(refund: 1800), _result(refund: true)),
        BookingStatus.paid,
      );

      expect(find.text('Возврат на карту'), findsOneWidget);
      expect(find.text('1\u00A0800 ₽'), findsOneWidget);
      expect(find.text('Срок зачисления'), findsOneWidget);
      expect(find.text('до 3 дней'), findsOneWidget);
      expect(find.text('0 / 2'), findsOneWidget);

      await _tap(tester, 'Да, отменить и вернуть деньги');
      expect(run.server.of('POST /bookings/b1/cancel'), hasLength(1));
      expect(find.text('Бронь отменена'), findsOneWidget);
      expect(
        find.text('Заявка на возврат 1\u00A0800 ₽ отправлена администратору. Деньги вернутся на ту же карту в течение 3 дней.'),
        findsOneWidget,
      );

      await _tap(tester, 'На главную');
      expect(run.opened[AppRoutes.shell], [0]);
      expect(run.results, [true]);
    });

    testWidgets('willBlock = true: два окна, затем «Аккаунт временно заблокирован», затем экран возврата', (tester) async {
      final run = await _start(
        tester,
        _server(_preview(count: 1, willBlock: true, refund: 1800), _result(count: 2, blocked: true, refund: true)),
        BookingStatus.paid,
      );

      // «Детали поездки - Лимит отмен»: строки возврата как в «Детали поездки - Отмена брони».
      expect(find.text('Возврат на карту'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      await _tap(tester, 'Да, отменить');

      expect(find.text('Это может повлиять на ваш аккаунт'), findsOneWidget);
      await _tap(tester, 'Всё равно отменить');
      expect(find.text('Аккаунт временно заблокирован'), findsOneWidget);

      await _tap(tester, 'Понятно');
      expect(find.text('Аккаунт временно заблокирован'), findsNothing);
      expect(find.text('Бронь отменена'), findsOneWidget);
      expect(find.textContaining('1\u00A0800 ₽'), findsOneWidget);

      await _tap(tester, 'На главную');
      expect(run.opened[AppRoutes.shell], [0]);
      expect(run.results, [true]);
    });

    testWidgets('«Не отменять» во втором окне: отмена не вызвана', (tester) async {
      final run = await _start(
        tester,
        _server(_preview(count: 1, willBlock: true, refund: 1800)),
        BookingStatus.paid,
      );
      await _tap(tester, 'Да, отменить');
      await _tap(tester, 'Не отменять');

      expect(run.server.of('POST /bookings/b1/cancel'), isEmpty);
      expect(run.results, [false]);
    });
  });

  group('ошибки', () {
    testWidgets('invalid_transition: подсказка по коду, экран входа перечитывает бронь (true)', (tester) async {
      final server = _server(_preview())
        ..on('POST /bookings/b1/cancel', (_) => const FakeReply(409, {'code': 'invalid_transition', 'message': 'x'}));
      final run = await _start(tester, server, BookingStatus.awaitingPayment);

      await _tap(tester, 'Да, отменить');
      expect(find.text('Статус брони уже изменился'), findsOneWidget);
      expect(find.text('Бронь отменена'), findsNothing);
      expect(run.results, [true]);
    });

    testWidgets('предпросмотр не загрузился: подсказка, окна нет, результат false', (tester) async {
      final server = FakeServer()
        ..on('GET /bookings/b1/cancel-preview', (_) => const FakeReply(500, {'code': 'internal', 'message': 'x'}));
      final run = await _start(tester, server, BookingStatus.awaitingPayment);

      expect(find.text('Отменить бронирование?'), findsNothing);
      expect(find.text('Не удалось выполнить действие. Попробуйте ещё раз'), findsOneWidget);
      expect(run.results, [false]);
    });
  });

  group('экран блокировки «Бронь отменена»', () {
    testWidgets('у водителя вторая фраза — про публикацию; маршрут назван system/temp_blocked', (tester) async {
      expect(TempBlockedScreen.route(TempBlockedRole.driver).settings.name, 'system/temp_blocked');

      await tester.pumpWidget(
        testApp(fakeSession(FakeServer()), const TempBlockedScreen(role: TempBlockedRole.driver)),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      expect(find.text('Аккаунт временно заблокирован'), findsOneWidget);
      expect(
        find.text('Вы отменили две поездки за последние 30 дней. Публикация новых поездок временно недоступна'),
        findsOneWidget,
      );
      expect(find.text('Информация о блокировке передана администратору приложения'), findsOneWidget);
    });
  });

  // Отказ от отклика на заказ до оплаты в счёт 2/30 не идёт: судья — `CancelPreview.counts`.
  group('бронь из заказа: counts = false', () {
    for (final fromAnswer in [false, true]) {
      testWidgets('окно «Отменить заявку?» без счётчика и без второго окна (fromAnswer: $fromAnswer)', (tester) async {
        final run = await _start(
          tester,
          _server({..._preview(count: 1, willBlock: true), 'counts': false}),
          BookingStatus.awaitingPayment,
          fromAnswer: fromAnswer,
        );

        expect(find.text('Отменить заявку?'), findsOneWidget);
        expect(
          find.text('Водитель откликнулся на ваш заказ. Отказ не повлияет на ваш аккаунт, заказ снова увидят другие водители.'),
          findsOneWidget,
        );
        expect(find.text('Отмен за 30 дней'), findsNothing);
        expect(find.textContaining('/ 2'), findsNothing);

        await _tap(tester, 'Отменить заявку');
        expect(find.text('Это может повлиять на ваш аккаунт'), findsNothing, reason: 'не в счёт — второго окна нет');
        expect(run.server.of('POST /bookings/b1/cancel'), hasLength(1));
        expect(find.text('Бронь отменена'), findsOneWidget);
        expect(run.results, [true]);
      });
    }

    testWidgets('counts = true у той же брони — прежнее окно со счётчиком', (tester) async {
      await _start(tester, _server({..._preview(), 'counts': true}), BookingStatus.awaitingPayment);
      expect(find.text('Отменить бронирование?'), findsOneWidget);
      expect(find.text('0 / 2'), findsOneWidget);
    });
  });
}
