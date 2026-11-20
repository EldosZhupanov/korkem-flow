/// A server on this very computer, reached without the wait Windows puts
/// in front of every new connection to «localhost» (owner, 20.11.2026:
/// «почему долго загружает?»).
///
/// Windows resolves `localhost` — and any `*.localhost` — to the IPv6
/// `::1` first. The bench runs in WSL, which forwards IPv4 only, so each
/// new connection first knocks on `::1`, is refused, and only then goes to
/// `127.0.0.1`. Measured on the owner's laptop: 0.21 s to connect by name,
/// 0.001 s by address — and a screen that opens with a dozen requests and a
/// grid of decor pictures pays it again and again.
///
/// So a plain-HTTP address on this computer is dialled as `127.0.0.1`, and
/// the name it was given travels in the `Host` header: a bench serving
/// several sites tells them apart by it. Anything else is left as it is.
typedef FastEndpoint = ({String url, Map<String, String>? headers});

FastEndpoint fastLoopback(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'http') return (url: url, headers: null);
  final host = uri.host.toLowerCase();
  if (host != 'localhost' && !host.endsWith('.localhost')) {
    return (url: url, headers: null);
  }
  return (
    url: uri.replace(host: '127.0.0.1').toString(),
    headers: host == 'localhost'
        ? null
        : {'Host': uri.hasPort ? '$host:${uri.port}' : host},
  );
}
