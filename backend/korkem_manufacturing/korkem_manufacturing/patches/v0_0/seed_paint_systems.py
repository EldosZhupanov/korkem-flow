"""Every company gets the colour systems, the popular colours, and its own
colours filed by their number (`services/mdf_paints.py`)."""

from korkem_manufacturing.services import mdf_paints


def execute():
	mdf_paints.seed_all_companies()
