/// Frappe stores several user-facing strings as HTML fragments.
///
/// `Notification Log.subject` is the clearest case — it arrives as
/// `<strong>Administrator</strong> assigned a new task ...` — and rendering it
/// raw would put tag names on screen. Stripping is the right call rather than
/// rendering the HTML: these fragments carry emphasis, not structure, and a
/// notification list wants one consistent type scale.
String stripHtml(String input) {
  return input
      .replaceAll(RegExp('<[^>]*>'), '')
      // Frappe emits the common entities; anything rarer is left alone rather
      // than half-decoded, which would be worse than showing it.
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
