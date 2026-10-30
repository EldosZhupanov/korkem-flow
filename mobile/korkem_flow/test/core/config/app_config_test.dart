import 'package:flutter_test/flutter_test.dart';
import 'package:korkem_flow/core/config/app_config.dart';

void main() {
  group('a development build is left alone', () {
    test('the local bench default is fine', () {
      const config = AppConfig(
        baseUrl: 'http://korkem.localhost:8000',
        flavor: 'dev',
      );
      expect(config.validate, returnsNormally);
      expect(config.isProduction, isFalse);
    });

    test('so is the address an emulator reaches its host on', () {
      const config = AppConfig(baseUrl: 'http://10.0.2.2:8000', flavor: 'dev');
      expect(config.validate, returnsNormally);
    });
  });

  group('a production build must ship a real server', () {
    test('a real https host passes', () {
      const config = AppConfig(
        baseUrl: 'https://korkem.example.com',
        flavor: 'prod',
      );
      expect(config.validate, returnsNormally);
      expect(config.isProduction, isTrue);
    });

    test('the compiled-in development default is refused', () {
      const config = AppConfig(
        baseUrl: 'http://korkem.localhost:8000',
        flavor: 'prod',
      );
      expect(config.validate, throwsStateError);
    });

    test('plain http is refused even against a real host', () {
      const config = AppConfig(
        baseUrl: 'http://korkem.example.com',
        flavor: 'prod',
      );
      expect(config.validate, throwsStateError);
    });

    test('every address meaning "this device" is refused', () {
      for (final host in [
        'localhost',
        '127.0.0.1',
        '0.0.0.0',
        '10.0.2.2',
        'anything.localhost',
      ]) {
        expect(
          AppConfig(baseUrl: 'https://$host', flavor: 'prod').validate,
          throwsStateError,
          reason: host,
        );
      }
    });

    test('a URL with no host at all is refused', () {
      const config = AppConfig(baseUrl: 'not a url', flavor: 'prod');
      expect(config.validate, throwsStateError);
    });

    test('the refusal names the variable an operator has to set', () {
      const config = AppConfig(
        baseUrl: 'http://korkem.localhost:8000',
        flavor: 'prod',
      );
      expect(
        () => config.validate(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('KORKEM_BASE_URL'),
          ),
        ),
      );
    });
  });
}
