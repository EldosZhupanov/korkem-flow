app_name = "korkem_ai"
app_title = "Korkem Ai"
app_publisher = "KORKEM"
app_description = "KORKEM Flow AI Orchestrator data layer: Agent Conversation, Agent Message, Pending Action."
app_email = "dev@korkem.local"
app_license = "mit"

# Send non-GET requests for this app's endpoints as native `application/json`
# bodies instead of form-encoded, per-key JSON-stringified values.
use_json_request_body = True

# Apps
# ------------------

# required_apps = []

# Each item in the list will be shown as an app in the apps page
# add_to_apps_screen = [
# 	{
# 		"name": "korkem_ai",
# 		"logo": "/assets/korkem_ai/logo.png",
# 		"title": "Korkem Ai",
# 		"route": "/korkem_ai",
# 		"has_permission": "korkem_ai.api.permission.has_app_permission",
# 	}
# ]

# Companion apps that extend a host app (instead of taking their own apps-screen icon) can pin
# their workspaces into the host app's workspace dock (rail) with this hook. Declaring it keeps
# the app off the apps screen, so it takes precedence over any add_to_apps_screen above. Who can
# see a pinned workspace is controlled by that workspace's own Roles table.
# add_to_workspace_dock = [
# 	{
# 		"app": "erpnext",
# 		"workspace": "My Workspace",
# 	}
# ]

# Deployment health
# ------------------
#
# `/health` and `/health/ready`, served as JSON to a caller with no session —
# a Docker healthcheck, a load balancer, an uptime monitor. Frappe consults
# `page_renderer` before every built-in renderer, so these two paths are never
# redirected to a login page and never rendered as a website 404.
page_renderer = ["korkem_ai.korkem_ai.health.HealthPage"]

# Includes in <head>
# ------------------

# include js, css files in header of desk.html
# app_include_css = "/assets/korkem_ai/css/korkem_ai.css"
# app_include_js = "/assets/korkem_ai/js/korkem_ai.js"

# include js, css files in header of web template
# web_include_css = "/assets/korkem_ai/css/korkem_ai.css"
# web_include_js = "/assets/korkem_ai/js/korkem_ai.js"

# include custom scss in every website theme (without file extension ".scss")
# website_theme_scss = "korkem_ai/public/scss/website"

# include js, css files in header of web form
# webform_include_js = {"doctype": "public/js/doctype.js"}
# webform_include_css = {"doctype": "public/css/doctype.css"}

# include js in page
# page_js = {"page" : "public/js/file.js"}

# include js in doctype views
# doctype_js = {"doctype" : "public/js/doctype.js"}
# doctype_list_js = {"doctype" : "public/js/doctype_list.js"}
# doctype_tree_js = {"doctype" : "public/js/doctype_tree.js"}
# doctype_calendar_js = {"doctype" : "public/js/doctype_calendar.js"}

# Svg Icons
# ------------------
# include app icons in desk
# app_include_icons = "korkem_ai/public/icons.svg"

# Home Pages
# ----------

# application home page (will override Website Settings)
# home_page = "login"

# website user home page (by Role)
# role_home_page = {
# 	"Role": "home_page"
# }

# Generators
# ----------

# automatically create page for each record of this doctype
# website_generators = ["Web Page"]

# automatically load and sync documents of this doctype from downstream apps
# importable_doctypes = [doctype_1]

# Jinja
# ----------

# add methods and filters to jinja environment
# jinja = {
# 	"methods": "korkem_ai.utils.jinja_methods",
# 	"filters": "korkem_ai.utils.jinja_filters"
# }

# Installation
# ------------

# Record the monotonic KORKEM schema marker only after Frappe commits a
# successful migration. The callback registration and rollback boundary live
# in environment.py, beside the startup comparison that consumes the marker.
after_migrate = [
	"korkem_ai.korkem_ai.permissions.apply",
	"korkem_ai.korkem_ai.environment.record_schema_version_after_migrate",
]

# before_install = "korkem_ai.install.before_install"
after_install = "korkem_ai.korkem_ai.permissions.apply"

# Uninstallation
# ------------

# before_uninstall = "korkem_ai.uninstall.before_uninstall"
# after_uninstall = "korkem_ai.uninstall.after_uninstall"

# Integration Setup
# ------------------
# To set up dependencies/integrations with other apps
# Name of the app being installed is passed as an argument

# before_app_install = "korkem_ai.utils.before_app_install"
# after_app_install = "korkem_ai.utils.after_app_install"

# Integration Cleanup
# -------------------
# To clean up dependencies/integrations with other apps
# Name of the app being uninstalled is passed as an argument

# before_app_uninstall = "korkem_ai.utils.before_app_uninstall"
# after_app_uninstall = "korkem_ai.utils.after_app_uninstall"

# Build
# ------------------
# To hook into the build process

# after_build = "korkem_ai.build.after_build"

# Desk Notifications
# ------------------
# See frappe.core.notifications.get_notification_config

# notification_config = "korkem_ai.notifications.get_notification_config"

# Permissions
# -----------
# Permissions evaluated in scripted ways

permission_query_conditions = {
	"Pending Action": (
		"korkem_ai.korkem_ai.doctype.pending_action.pending_action."
		"get_permission_query_conditions"
	),
}

has_permission = {
	"Pending Action": "korkem_ai.korkem_ai.doctype.pending_action.pending_action.has_permission",
	# Frappe 17 registers a *list* condition for Notification Log
	# (`for_user = session.user`) and no document-level check, so a named GET
	# returns somebody else's notification. Measured on a bench built from
	# nothing, twice, once with the whole suite: the list hides it and the
	# document hands it over. See korkem_ai/permissions.py for the boundary.
	"Notification Log": "korkem_ai.korkem_ai.permissions.notification_log_has_permission",
}

# Document Events
# ---------------
# Hook on document methods and events

# Outbound customer notification when a production task finishes. Hooked here
# independently of korkem_manufacturing's hook on the same doctype: this app owns
# the customer channel, that app owns shop-floor progress. Frappe runs both.
doc_events = {
	"CRM Task": {
		"on_update": "korkem_ai.korkem_ai.notifications.on_task_update",
	}
}

# Scheduled Tasks
# ---------------

scheduler_events = {
	"hourly": [
		"korkem_ai.korkem_ai.doctype.pending_action.pending_action.expire_stale_pending_actions"
	],
	# Notifications whose backoff has elapsed. On the scheduler rather than in a
	# sleeping worker: a retry that holds a queue slot for sixteen minutes costs
	# more than the message is worth.
	"cron": {
		"*/5 * * * *": [
			"korkem_ai.korkem_ai.doctype.notification_delivery.notification_delivery.retry_due"
		]
	},
}

# Domain events
# -------------
#
# `korkem_manufacturing` announces business events by name and does not know
# who listens; this app subscribes. That direction is the whole point — a
# domain that imported its own notification layer could not be reached by a
# desktop client or a terminal without dragging the orchestrator along
# (ADR-0003, ADR-0006, ADR-0007).
#
# Each subscriber runs inside its own savepoint on the domain's side, so an
# undeliverable notification cannot roll back a stock movement that has
# already happened.
korkem_domain_events = {
	"production.started": ["korkem_ai.korkem_ai.notifications.events.production_started"],
	"production.material_short": ["korkem_ai.korkem_ai.notifications.events.material_short"],
}


# Testing
# -------

before_tests = "korkem_ai.install.before_tests"

# Extend DocType Class
# ------------------------------
#
# Specify custom mixins to extend the standard doctype controller.
# extend_doctype_class = {
# 	"Task": "korkem_ai.custom.task.CustomTaskMixin"
# }

# Overriding Methods
# ------------------------------
#
# override_whitelisted_methods = {
# 	"frappe.desk.doctype.event.event.get_events": "korkem_ai.event.get_events"
# }
#
# each overriding function accepts a `data` argument;
# generated from the base implementation of the doctype dashboard,
# along with any modifications made in other Frappe apps
# override_doctype_dashboards = {
# 	"Task": "korkem_ai.task.get_dashboard_data"
# }

# exempt linked doctypes from being automatically cancelled
#
# auto_cancel_exempted_doctypes = ["Auto Repeat"]

# Ignore links to specified DocTypes when deleting documents
# -----------------------------------------------------------

# ignore_links_on_delete = ["Communication", "ToDo"]

# Request Events
# ----------------
# before_request = ["korkem_ai.utils.before_request"]
# after_request = ["korkem_ai.utils.after_request"]

# Job Events
# ----------
# before_job = ["korkem_ai.utils.before_job"]
# after_job = ["korkem_ai.utils.after_job"]

# after_file_upload = ["korkem_ai.utils.after_file_upload"]

# User Data Protection
# --------------------

# user_data_fields = [
# 	{
# 		"doctype": "{doctype_1}",
# 		"filter_by": "{filter_by}",
# 		"redact_fields": ["{field_1}", "{field_2}"],
# 		"partial": 1,
# 	},
# 	{
# 		"doctype": "{doctype_2}",
# 		"filter_by": "{filter_by}",
# 		"partial": 1,
# 	},
# 	{
# 		"doctype": "{doctype_3}",
# 		"strict": False,
# 	},
# 	{
# 		"doctype": "{doctype_4}"
# 	}
# ]

# Authentication and authorization
# --------------------------------

# auth_hooks = [
# 	"korkem_ai.auth.validate"
# ]

# Automatically update python controller files with type annotations for this app.
export_python_type_annotations = True

# Require all whitelisted methods to have type annotations
require_type_annotated_api_methods = True

# default_log_clearing_doctypes = {
# 	"Logging DocType Name": 30  # days to retain logs
# }

# Translation
# ------------
# List of apps whose translatable strings should be excluded from this app's translations.
# ignore_translatable_strings_from = []
