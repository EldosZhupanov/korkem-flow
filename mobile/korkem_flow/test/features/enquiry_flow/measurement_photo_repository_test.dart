import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';
import 'package:korkem_flow/features/enquiry_flow/data/measurement_photo_repository.dart';

Dio createDio(Future<ResponseBody> Function(RequestOptions) handler) {
  return Dio()..httpClientAdapter = _TestAdapter(handler);
}

class _TestAdapter implements HttpClientAdapter {
  _TestAdapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);

  @override
  void close({bool force = false}) {}
}

void main() {
  group('MeasurementPhotoRepository', () {
    test('attach returns empty list when no photos provided', () async {
      final dio = createDio((_) async => throw UnimplementedError());
      final client = FrappeClient(dio);
      final repo = MeasurementPhotoRepository(client);

      final result = await repo.attach('OPP-001', []);
      expect(result, isEmpty);
    });

    test('снимок уходит на сервер, а не остаётся именем файла', () async {
      final sent = <RequestOptions>[];
      var counter = 0;
      final dio = createDio((options) async {
        sent.add(options);
        counter++;
        return ResponseBody.fromString(
          '{"message":{"file_name":"замер-00000$counter.jpg",'
          '"status":"attached"}}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });
      final repo = MeasurementPhotoRepository(FrappeClient(dio));

      final result = await repo.attach('OPP-001', [
        XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'wall_socket.jpg'),
        XFile.fromData(Uint8List.fromList([4, 5, 6]), name: 'corner_pipes.jpg'),
      ]);

      // Имена приходят от сервера. Имя файла с телефона пишет отправитель, и
      // сервер его переписывает — принять присланное значило бы показать
      // замерщику имя, которого на сервере нет.
      expect(result, ['замер-000001.jpg', 'замер-000002.jpg']);

      // По одному запросу на снимок, на нужный endpoint.
      expect(sent.length, 2);
      expect(
        sent.first.path,
        '/api/method/${MeasurementPhotoRepository.attachPhotoEndpoint}',
      );
      expect(sent.first.data, isA<FormData>());
    });

    test('не ушедший снимок — это ошибка, а не тихий успех', () async {
      final dio = createDio((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      });
      final repo = MeasurementPhotoRepository(FrappeClient(dio));

      await expectLater(
        repo.attach('OPP-001', [
          XFile.fromData(Uint8List.fromList([1]), name: 'wall.jpg'),
        ]),
        throwsA(anything),
      );
    });
  });
}
