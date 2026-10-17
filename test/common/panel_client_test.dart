import 'package:ckbox/common/panel_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PanelClient.detectIsXboard', () {
    test('Bearer 前缀识别为 Xboard', () {
      expect(PanelClient.detectIsXboard('Bearer abc123'), isTrue);
      expect(PanelClient.detectIsXboard('Bearer 1|xyz'), isTrue);
    });

    test('裸 JWT 识别为 v2board', () {
      expect(
        PanelClient.detectIsXboard('eyJhbGciOiJIUzI1NiJ9.eyJpZCI6MX0.sig'),
        isFalse,
      );
    });

    test('空字符串按 v2board 处理（无 Bearer）', () {
      expect(PanelClient.detectIsXboard(''), isFalse);
    });
  });

  group('PanelClient.normalizePanelUrl', () {
    test('去掉单个尾部斜杠', () {
      expect(
        PanelClient.normalizePanelUrl('https://panel.example.com/'),
        'https://panel.example.com',
      );
    });

    test('去掉多个尾部斜杠', () {
      expect(
        PanelClient.normalizePanelUrl('https://panel.example.com///'),
        'https://panel.example.com',
      );
    });

    test('无斜杠保持原样', () {
      expect(
        PanelClient.normalizePanelUrl('https://panel.example.com'),
        'https://panel.example.com',
      );
    });

    test('去掉首尾空白', () {
      expect(
        PanelClient.normalizePanelUrl('  https://panel.example.com/  '),
        'https://panel.example.com',
      );
    });
  });
}
