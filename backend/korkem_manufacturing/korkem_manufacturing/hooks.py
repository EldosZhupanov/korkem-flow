app_name = "korkem_manufacturing"
app_title = "Korkem Manufacturing"
app_publisher = "KORKEM"
app_description = "KORKEM Flow manufacturing extensions on top of ERPNext (Facade Item, Decor, Milling Profile)."
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
# 		"name": "korkem_manufacturing",
# 		"logo": "/assets/korkem_manufacturing/logo.png",
# 		"title": "Korkem Manufacturing",
# 		"route": "/korkem_manufacturing",
# 		"has_permission": "korkem_manufacturing.api.permission.has_app_permission",
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

# Includes in <head>
# ------------------

# include js, css files in header of desk.html
# app_include_css = "/assets/korkem_manufacturing/css/korkem_manufacturing.css"
# app_include_js = "/assets/korkem_manufacturing/js/korkem_manufacturing.js"

# include js, css files in header of web template
# web_include_css = "/assets/korkem_manufacturing/css/korkem_manufacturing.css"
# web_include_js = "/assets/korkem_manufacturing/js/korkem_manufacturing.js"

# include custom scss in every website theme (without file extension ".scss")
# website_theme_scss = "korkem_manufacturing/public/scss/website"

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
# app_include_icons = "korkem_manufacturing/public/icons.svg"

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
# 	"methods": "korkem_manufacturing.utils.jinja_methods",
# 	"filters": "korkem_manufacturing.utils.jinja_filters"
# }

# Installation
# ------------

# before_install = "korkem_manufacturing.install.before_install"
# after_install = "korkem_manufacturing.install.after_install"

# Uninstallation
# ------------

# before_uninstall = "korkem_manufacturing.uninstall.before_uninstall"
# after_uninstall = "korkem_manufacturing.uninstall.after_uninstall"

# Integration Setup
# ------------------
# To set up dependencies/integrations with other apps
# Name of the app being installed is passed as an argument

# before_app_install = "korkem_manufacturing.utils.before_app_install"
# after_app_install = "korkem_manufacturing.utils.after_app_install"

# Integration Cleanup
# -------------------
# To clean up dependencies/integrations with other apps
# Name of the app being uninstalled is passed as an argument

# before_app_uninstall = "korkem_manufacturing.utils.before_app_uninstall"
# after_app_uninstall = "korkem_manufacturing.utils.after_app_uninstall"

# Build
# ------------------
# To hook into the build process

# after_build = "korkem_manufacturing.build.after_build"

# Desk Notifications
# ------------------
# See frappe.core.notifications.get_notification_config

# notification_config = "korkem_manufacturing.notifications.get_notification_config"

# Permissions
# -----------
# Permissions evaluated in scripted ways

# permission_query_conditions = {
# 	"Event": "frappe.desk.doctype.event.event.get_permission_query_conditions",
# }
#
# has_permission = {
# 	"Event": "frappe.desk.doctype.event.event.has_permission",
# }

# Document Events
# ---------------
# Hook on document methods and events

# A worker completing a shop-floor task is caught here rather than only inside
# shop_floor.complete_task(), so that finishing the task from the Desk UI has
# exactly the same effects as calling the API. korkem_ai hooks this same doctype
# separately for the customer notification -- neither app imports the other.
doc_events = {
	"CRM Task": {
		"on_update": "korkem_manufacturing.shop_floor.on_task_update",
	}
}

# Scheduled Tasks
# ---------------

# scheduler_events = {
# 	"all": [
# 		"korkem_manufacturing.tasks.all"
# 	],
# 	"daily": [
# 		"korkem_manufacturing.tasks.daily"
# 	],
# 	"hourly": [
# 		"korkem_manufacturing.tasks.hourly"
# 	],
# 	"weekly": [
# 		"korkem_manufacturing.tasks.weekly"
# 	],
# 	"monthly": [
# 		"korkem_manufacturing.tasks.monthly"
# 	],
# }

# Testing
# -------

# before_tests = "korkem_manufacturing.install.before_tests"

# Extend DocType Class
# ------------------------------
#
# Specify custom mixins to extend the standard doctype controller.
# extend_doctype_class = {
# 	"Task": "korkem_manufacturing.custom.task.CustomTaskMixin"
# }

# Overriding Methods
# ------------------------------
#
# override_whitelisted_methods = {
# 	"frappe.desk.doctype.event.event.get_events": "korkem_manufacturing.event.get_events"
# }
#
# each overriding function accepts a `data` argument;
# generated from the base implementation of the doctype dashboard,
# along with any modifications made in other Frappe apps
# override_doctype_dashboards = {
# 	"Task": "korkem_manufacturing.task.get_dashboard_data"
# }

# exempt linked doctypes from being automatically cancelled
#
# auto_cancel_exempted_doctypes = ["Auto Repeat"]

# Ignore links to specified DocTypes when deleting documents
# -----------------------------------------------------------

# ignore_links_on_delete = ["Communication", "ToDo"]

# Request Events
# ----------------
# before_request = ["korkem_manufacturing.utils.before_request"]
# after_request = ["korkem_manufacturing.utils.after_request"]

# Job Events
# ----------
# before_job = ["korkem_manufacturing.utils.before_job"]
# after_job = ["korkem_manufacturing.utils.after_job"]

# after_file_upload = ["korkem_manufacturing.utils.after_file_upload"]

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
# 	"korkem_manufacturing.auth.validate"
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

