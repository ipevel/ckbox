import 'package:ckbox/models/panel_account.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PanelAccount toJson/fromJson 往返', () {
    final account = PanelAccount(
      id: '1720000000000',
      panelUrl: 'https://panel.example.com',
      email: 'test@example.com',
      authData: 'Bearer abc123',
      isXboard: true,
      subscribeToken: 'sub-token',
      subscribeUrl: 'https://panel.example.com/s/sub-token',
      expireAt: 1735689600,
      totalTraffic: 1073741824,
      upload: 1048576,
      download: 2097152,
    );

    final restored = PanelAccount.fromJson(account.toJson());

    expect(restored.id, account.id);
    expect(restored.panelUrl, account.panelUrl);
    expect(restored.email, account.email);
    expect(restored.authData, account.authData);
    expect(restored.isXboard, true);
    expect(restored.subscribeToken, account.subscribeToken);
    expect(restored.subscribeUrl, account.subscribeUrl);
    expect(restored.expireAt, account.expireAt);
    expect(restored.totalTraffic, account.totalTraffic);
    expect(restored.upload, account.upload);
    expect(restored.download, account.download);
  });

  test('copyWith 只更新指定字段', () {
    final account = PanelAccount(
      id: '1',
      panelUrl: 'https://p.example.com',
      email: 'a@b.com',
      authData: 'Bearer x',
      isXboard: true,
      subscribeToken: 't',
      subscribeUrl: 'https://p.example.com/s/t',
      expireAt: 100,
    );

    final updated = account.copyWith(authData: 'Bearer y', expireAt: 200);

    expect(updated.id, account.id);
    expect(updated.authData, 'Bearer y');
    expect(updated.expireAt, 200);
    expect(updated.subscribeUrl, account.subscribeUrl);
    expect(updated.isXboard, true);
  });
}
