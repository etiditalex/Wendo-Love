import 'package:flutter_test/flutter_test.dart';
import 'package:upendo_pamoja/nav.dart';

void main() {
  test('primary member tabs are recognized', () {
    expect(isPrimaryMemberTab('/app'), isTrue);
    expect(isPrimaryMemberTab('/app/discover'), isTrue);
    expect(isPrimaryMemberTab('/app/matches'), isTrue);
    expect(isPrimaryMemberTab('/app/messages'), isTrue);
    expect(isPrimaryMemberTab('/app/profile'), isTrue);
    expect(isPrimaryMemberTab('/app/settings'), isFalse);
    expect(isPrimaryMemberTab('/app/meet'), isFalse);
    expect(isPrimaryMemberTab('/'), isFalse);
  });
}
