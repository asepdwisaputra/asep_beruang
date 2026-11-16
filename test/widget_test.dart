import 'package:flutter_test/flutter_test.dart';

import 'package:asep_beruang/utils.dart';

void main() {
  test('formats Indonesian Rupiah with dot-separated thousands', () {
    expect(formatRupiah(1000000), 'Rp 1.000.000');
  });
}
