import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/frappe_client.dart';

final measurementPhotoRepositoryProvider = Provider<MeasurementPhotoRepository>(
  (ref) {
    return MeasurementPhotoRepository(ref.watch(frappeClientProvider));
  },
);

/// Снимки с замера — то, что словами не передаётся: розетка не на месте,
/// труба в углу, уклон пола.
class MeasurementPhotoRepository {
  const MeasurementPhotoRepository(this._client);

  final FrappeClient _client;

  FrappeClient get client => _client;

  /// Приложить снимки к заявке. Возвращает имена, под которыми их сохранил
  /// сервер, — они отличаются от присланных: имя файла с телефона означает
  /// ровно то, что в нём написал отправитель, и сервер его переписывает.
  ///
  /// По одному, а не пачкой: замерщик стоит на объекте с мобильной сетью, и
  /// восемь мегабайт одним запросом там не проходят. Если один снимок не ушёл,
  /// ошибка поднимается наверх, а выбранные фотографии остаются на экране — так
  /// человек видит, что именно не отправилось, и повторяет.
  Future<List<String>> attach(String enquiry, List<XFile> photos) async {
    final attached = <String>[];
    for (final photo in photos) {
      final response = await _client.uploadFile(
        attachPhotoEndpoint,
        field: 'file',
        filename: photo.name.isNotEmpty ? photo.name : 'замер.jpg',
        bytes: await photo.readAsBytes(),
        fields: <String, dynamic>{'enquiry': enquiry},
      );
      final message = response['message'];
      if (message is Map<String, dynamic>) {
        attached.add('${message['file_name'] ?? ''}');
      }
    }
    return attached;
  }

  static const attachPhotoEndpoint =
      'korkem_manufacturing.api.measurement.attach_photo';
}
