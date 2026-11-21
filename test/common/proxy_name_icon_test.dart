import 'package:fl_clash/common/proxy_name_icon.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void expectSplit(String name, String? icon, String title) {
    expect(splitProxyNameIcon(name), ProxyNameParts(icon, title), reason: name);
  }

  test('a flag becomes the icon, the other symbols stay in the title', () {
    expectSplit('★ 🇩🇪 Emerald', '🇩🇪', '★ Emerald');
    expectSplit('ϟ 🇩🇪 Германия', '🇩🇪', 'ϟ Германия');
    expectSplit('🇫🇮 Legacy · HY2 Alt', '🇫🇮', 'Legacy · HY2 Alt');
    expectSplit('★ 🇪🇪 Toompea', '🇪🇪', '★ Toompea');
    expectSplit('🏴󠁧󠁢󠁥󠁮󠁧󠁿 London', '🏴󠁧󠁢󠁥󠁮󠁧󠁿', 'London');
  });

  test('without a flag the first symbol becomes the icon', () {
    expectSplit('◈ Общий подбор', '◈', 'Общий подбор');
    expectSplit('≋ Стандарт', '≋', 'Стандарт');
    expectSplit('★ Звёздные (подбор)', '★', 'Звёздные (подбор)');
    expectSplit('ϟ Быстрый', 'ϟ', 'Быстрый');
    expectSplit('⚡ Fast', '⚡', 'Fast');
  });

  test('names without a prefix keep their title', () {
    expectSplit('Белые списки', null, 'Белые списки');
    expectSplit('DIRECT', null, 'DIRECT');
    expectSplit('В Германию', null, 'В Германию');
    expectSplit('5G Auto', null, '5G Auto');
    expectSplit('A1 Telekom', null, 'A1 Telekom');
    expectSplit('Авто LTE | 49 ГБ', null, 'Авто LTE | 49 ГБ');
  });

  test('a lone symbol is a name, not a prefix', () {
    expectSplit('★', null, '★');
    expectSplit('🇩🇪', null, '🇩🇪');
  });
}
