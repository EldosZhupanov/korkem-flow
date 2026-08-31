# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""The WSGI entry point a pilot's gunicorn serves.

    gunicorn korkem_ai.wsgi:application

## Why this file exists rather than `frappe.app:application`

Two things a Frappe deployment normally gets from nginx, which this one does not
have. The proxy here is Caddy in a separate container, and it can neither read
the bench's filesystem nor be told to rewrite the application's idea of itself.

**Static files.** `application_with_statics()` — Frappe's own factory, the one
`bench serve` uses — wraps the app so it serves `/assets` and `/files` itself.
Without it every stylesheet on the desk 404s.

**The scheme and the client address.** Behind a TLS terminator, gunicorn is
spoken to over plain HTTP on a private network, so `request.scheme` is `http`
and `request.remote_addr` is the proxy's container address. That is not cosmetic:

* `frappe/auth.py:set_cookie` derives the cookie's **`Secure` flag** from
  `request.scheme == "https"`. Left uncorrected, a pilot behind real TLS issues
  its session cookie *without* `Secure` — the one flag that stops a browser
  ever sending it in clear.
* `frappe.local.request_ip` is what rate limiting counts and what audit records.
  Left uncorrected, every visitor in the world is one IP address.

`ProxyFix` reads `X-Forwarded-Proto`, `-For`, `-Host`, `-Port` and `-Prefix` and
puts them back. The counts are all **1**: exactly one hop is trusted, the proxy
in front. That is sound here precisely because the application port is bound to
`127.0.0.1` and the proxy is the only route in — nobody else is in a position to
send those headers. Run without a proxy, no such headers arrive and ProxyFix
changes nothing.

These are the same arguments `frappe.app.serve()` uses for `--proxy`; the only
reason they are repeated here is that `serve()` is the development server and is
not what a pilot runs.
"""

from frappe.app import application_with_statics
from werkzeug.middleware.proxy_fix import ProxyFix

application = ProxyFix(
	application_with_statics(),
	x_for=1,
	x_proto=1,
	x_host=1,
	x_port=1,
	x_prefix=1,
)
