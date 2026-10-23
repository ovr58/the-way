import 'package:flutter_test/flutter_test.dart';
import 'package:the_way/src/app/http.dart';

void main() {
  test('traceparent по W3C: 00-<32 hex>-<16 hex>-01', () {
    final value = newTraceparent();
    expect(value, matches(RegExp(r'^00-[0-9a-f]{32}-[0-9a-f]{16}-01$')));
    expect(traceIdOf(value), hasLength(32));
    expect(newTraceparent(), isNot(value));
  });
}
