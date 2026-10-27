"""CRM's base currency becomes the company currency, so tenge needs no network."""

from korkem_manufacturing.services import crm_currency


def execute():
	crm_currency.align()
