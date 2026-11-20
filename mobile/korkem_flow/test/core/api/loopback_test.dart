import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/api/loopback.dart';

/// «Почему долго загружает?» (owner, 20.11.2026): a bench on this computer
/// is dialled by address, its name kept in the Host header.
void main() {
  void dialled(String given, String url, Map<String, String>? headers) {
    final e = fastLoopback(given);
    expect(e.url, url, reason: given);
    expect(e.headers, headers, reason: given);
  }

  test('localhost is dialled as 127.0.0.1', () {
    dialled('http://localhost:8002', 'http://127.0.0.1:8002', null);
  });

  test('a named site keeps its name in the Host header', () {
    dialled('http://work.localhost:8002', 'http://127.0.0.1:8002', {
      'Host': 'work.localhost:8002',
    });
    dialled('http://korkem.localhost', 'http://127.0.0.1', {
      'Host': 'korkem.localhost',
    });
  });

  test('a real server and HTTPS are left as they are', () {
    for (final url in [
      'https://api.korkem.asia',
      'https://localhost:8443',
      'http://10.0.2.2:8000',
      'http://192.168.1.5:8002',
    ]) {
      dialled(url, url, null);
    }
  });
}
