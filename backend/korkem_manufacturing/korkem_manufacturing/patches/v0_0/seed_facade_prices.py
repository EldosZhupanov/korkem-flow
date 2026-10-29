"""Give every existing company the factory's starting facade prices.

Only cells a company does not have are written; an edited price is left alone.
"""

from korkem_manufacturing.services import facade_prices


def execute():
	facade_prices.seed_all_companies()
