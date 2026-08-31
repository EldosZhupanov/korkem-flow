# Copyright (c) 2026, KORKEM and Contributors
# See license.txt
"""The pilot's WSGI entry point, and the two things it must not stop doing.

Both are invisible in development — the development server does them itself —
and both fail silently in a pilot: a session cookie missing its `Secure` flag
looks exactly like one that has it, and a rate limiter counting one address
looks exactly like one that is working.
"""

from frappe.tests import IntegrationTestCase
from werkzeug.middleware.proxy_fix import ProxyFix

from korkem_ai import wsgi


class TestThePilotEntryPoint(IntegrationTestCase):
	def test_it_exposes_a_wsgi_application(self):
		self.assertTrue(callable(wsgi.application))

	def test_it_corrects_the_forwarded_headers(self):
		self.assertIsInstance(wsgi.application, ProxyFix)

	def test_it_trusts_exactly_one_hop(self):
		"""More than one would let a client forge its own address."""
		for attribute in ("x_for", "x_proto", "x_host", "x_port", "x_prefix"):
			with self.subTest(attribute):
				self.assertEqual(getattr(wsgi.application, attribute), 1)

	def test_the_scheme_a_tls_proxy_reports_is_the_one_the_app_sees(self):
		"""`auth.set_cookie` reads this to decide the cookie's `Secure` flag."""
		seen = {}

		def spy(environ, start_response):
			seen.update(environ)
			return []

		proxied = ProxyFix(spy, x_for=1, x_proto=1, x_host=1, x_port=1, x_prefix=1)
		proxied(
			{
				"wsgi.url_scheme": "http",
				"REMOTE_ADDR": "172.18.0.9",
				"HTTP_X_FORWARDED_PROTO": "https",
				"HTTP_X_FORWARDED_FOR": "203.0.113.7",
			},
			lambda *_args: None,
		)

		self.assertEqual(seen["wsgi.url_scheme"], "https")
		self.assertEqual(seen["REMOTE_ADDR"], "203.0.113.7")

	def test_it_serves_the_static_files_itself(self):
		"""The proxy is a separate container and cannot read the bench's disk."""
		from werkzeug.middleware.shared_data import SharedDataMiddleware

		inner = wsgi.application.app
		wrappers = []
		while inner is not None and len(wrappers) < 5:
			wrappers.append(inner)
			inner = getattr(inner, "app", None)

		self.assertTrue(
			any(isinstance(wrapper, SharedDataMiddleware) for wrapper in wrappers),
			"the application is not wrapped to serve /assets and /files",
		)
