import 'package:url_launcher/url_launcher.dart';

/// Turns the contact fields on a record into things a phone can act on.
///
/// The URI builders are pure and public so they can be tested directly: the
/// launch itself is a platform call no unit test can observe, but getting
/// `tel:` and `wa.me` wrong is exactly the kind of bug that only shows up in a
/// salesperson's hand.
abstract final class ContactActions {
  /// `tel:` ignores formatting, but spaces and brackets break some diallers.
  static Uri? phoneUri(String? phone) {
    final digits = normaliseNumber(phone);
    return digits == null ? null : Uri(scheme: 'tel', path: digits);
  }

  static Uri? emailUri(String? address) {
    final trimmed = address?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return Uri(scheme: 'mailto', path: trimmed);
  }

  /// WhatsApp is how KORKEM's customers actually reach the company — the
  /// backend's only inbound integration is a WhatsApp webhook — so it earns a
  /// first-class action rather than living behind a share sheet.
  ///
  /// wa.me takes bare digits: it rejects the `+` that `tel:` requires.
  static Uri? whatsAppUri(String? phone) {
    final digits = normaliseNumber(phone)?.replaceAll('+', '');
    return digits == null ? null : Uri.parse('https://wa.me/$digits');
  }

  /// Frappe stores company websites without a scheme as often as with one, and
  /// a bare host parses as a relative path that launches nothing.
  static Uri? websiteUri(String? url) {
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;

    final absolute =
        trimmed.startsWith('http://') || trimmed.startsWith('https://')
        ? trimmed
        : 'https://$trimmed';
    return Uri.tryParse(absolute);
  }

  /// Strips formatting but keeps a leading `+`: without the country code,
  /// neither an international dial nor a wa.me link resolves.
  static String? normaliseNumber(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;

    final plus = trimmed.startsWith('+') ? '+' : '';
    final digits = trimmed.replaceAll(RegExp('[^0-9]'), '');
    return digits.isEmpty ? null : '$plus$digits';
  }

  static Future<bool> call(String? phone) => _launch(phoneUri(phone));

  static Future<bool> email(String? address) => _launch(emailUri(address));

  static Future<bool> whatsApp(String? phone) => _launch(whatsAppUri(phone));

  static Future<bool> openWebsite(String? url) => _launch(websiteUri(url));

  /// Best-effort: a device with no dialler — a tablet, a desktop build — must
  /// not throw an unhandled exception because someone tapped Call.
  static Future<bool> _launch(Uri? uri) async {
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception {
      return false;
    }
  }
}
