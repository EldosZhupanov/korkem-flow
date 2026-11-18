# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""How the general search reads what was typed (owner, 18.11.2026, variant Б).

Pure text, no database — so every rule here is tested on its own:

- **One letter is one letter.** Case, «ё»/«е» and the Kazakh letters
  (ә ғ қ ң ө ұ ү һ і) fold to their Russian neighbours, so «Ерлан», «ерлан»
  and «Ерлан» typed on the Kazakh layout are one name.
- **The wrong layout is forgiven.** Three layouts on one keyboard means
  «thkfy» is «ерлан» typed in English, and «ДЦ 611» is «LW 611» typed in
  Russian. Both readings are searched.
- **Latin spelling is read too:** «erlan» finds «Ерлан».
- **A typo is forgiven:** a word of 4–6 letters may be one letter off, a
  longer one two. «сиена вердэ» finds «сиена верде».
- **What it is decides where it looks:** a phone is matched by its digits,
  a short number is an order's number («245», «№245»).
"""

from __future__ import annotations

import re

_KAZ = str.maketrans({"ә": "а", "ғ": "г", "қ": "к", "ң": "н", "ө": "о", "ұ": "у", "ү": "у", "һ": "х",
					  "і": "и", "ё": "е", "й": "и"})

# The same keys on the English and the Russian layout.
_EN = "qwertyuiop[]asdfghjkl;'zxcvbnm,.`"
_RU = "йцукенгшщзхъфывапролджэячсмитьбюё"
_EN_TO_RU = str.maketrans(_EN, _RU)
_RU_TO_EN = str.maketrans(_RU, _EN)

# Latin spelling of Russian and Kazakh names, longest first.
_LATIN = (
	("shch", "щ"), ("sch", "щ"), ("zh", "ж"), ("kh", "х"), ("ch", "ч"), ("sh", "ш"), ("ts", "ц"),
	("yu", "ю"), ("ya", "я"), ("yo", "е"), ("ye", "е"),
	("a", "а"), ("b", "б"), ("c", "к"), ("d", "д"), ("e", "е"), ("f", "ф"), ("g", "г"), ("h", "х"),
	("i", "и"), ("j", "ж"), ("k", "к"), ("l", "л"), ("m", "м"), ("n", "н"), ("o", "о"), ("p", "п"),
	("q", "к"), ("r", "р"), ("s", "с"), ("t", "т"), ("u", "у"), ("v", "в"), ("w", "у"), ("x", "кс"),
	("y", "и"), ("z", "з"),
)

_WORD = re.compile(r"[0-9a-zа-я]+")
_PHONE = re.compile(r"^[\d\s()+\-]+$")
_NUMBER = re.compile(r"^[№#]?\s*(\d{1,6})$")


def fold(text: str | None) -> str:
	"""Lower case, Kazakh letters and «ё» as their Russian neighbours, one space."""
	return " ".join(str(text or "").casefold().translate(_KAZ).split())


def compact(text: str | None) -> str:
	"""Folded, with no spaces or punctuation: «LW 611-2» → «lw6112»."""
	return "".join(_WORD.findall(fold(text)))


def words(text: str | None) -> list[str]:
	return _WORD.findall(fold(text))


def _latin_to_cyrillic(text: str) -> str:
	out, i = [], 0
	while i < len(text):
		for latin, cyrillic in _LATIN:
			if text.startswith(latin, i):
				out.append(cyrillic)
				i += len(latin)
				break
		else:
			out.append(text[i])
			i += 1
	return "".join(out)


def variants(query: str | None) -> list[str]:
	"""Every reading of what was typed, the typed one first, none twice."""
	typed = fold(query)
	if not typed:
		return []
	found = [typed]
	raw = str(query or "").casefold()
	has_latin = re.search(r"[a-z]", typed) is not None
	has_cyrillic = re.search(r"[а-я]", typed) is not None
	if has_latin and not has_cyrillic:
		found.append(fold(raw.translate(_EN_TO_RU)))
		found.append(fold(_latin_to_cyrillic(typed)))
	if has_cyrillic and not has_latin:
		found.append(fold(raw.translate(_RU_TO_EN)))
	return list(dict.fromkeys(v for v in found if v))


def digits(text: str | None) -> str:
	return "".join(ch for ch in str(text or "") if ch.isdigit())


def phone_of(query: str | None) -> str | None:
	"""The digits to look for in phones, if what was typed reads as one."""
	text = str(query or "").strip()
	found = digits(text)
	if len(found) < 5 or not _PHONE.match(text):
		return None
	# 8 701… and +7 701… are one phone: compare the last ten digits.
	return found[-10:] if len(found) > 10 else (found[1:] if len(found) == 11 else found)


def number_of(query: str | None) -> int | None:
	"""An order's number, if what was typed reads as one: «245», «№ 245»."""
	match = _NUMBER.match(str(query or "").strip())
	return int(match.group(1)) if match and int(match.group(1)) > 0 else None


def number_in(name: str | None) -> int | None:
	"""The number at the end of a document name: «SAL-ORD-2026-00245» → 245."""
	match = re.search(r"(\d+)\s*$", str(name or ""))
	return int(match.group(1)) if match else None


def _distance(a: str, b: str, limit: int) -> int:
	"""Levenshtein distance, giving up past `limit`."""
	if abs(len(a) - len(b)) > limit:
		return limit + 1
	previous = list(range(len(b) + 1))
	for i, ca in enumerate(a, 1):
		current = [i]
		for j, cb in enumerate(b, 1):
			current.append(min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (ca != cb)))
		if min(current) > limit:
			return limit + 1
		previous = current
	return previous[-1]


def _tolerance(word: str) -> int:
	if len(word) >= 7:
		return 2
	return 1 if len(word) >= 4 else 0


def _word_score(word: str, candidates: list[str]) -> float:
	best = 0.0
	for candidate in candidates:
		if candidate == word:
			return 3.0
		if candidate.startswith(word):
			best = max(best, 2.5)
		elif len(word) >= 3 and word in candidate:
			best = max(best, 1.5)
		else:
			limit = _tolerance(word)
			if limit and (
				_distance(word, candidate, limit) <= limit
				or _distance(word, candidate[: len(word)], limit) <= limit
			):
				best = max(best, 1.0)
	return best


def score(readings: list[str], *texts: str | None) -> float:
	"""How well the typed text matches these fields; 0 — not at all.

	Every word typed has to be found among the fields' words — whole, as the
	start of one, inside one, or a letter or two off — under any reading.
	"""
	haystack = " ".join(fold(t) for t in texts if t)
	if not haystack:
		return 0.0
	targets = _WORD.findall(haystack)
	squeezed = compact(haystack)
	best = 0.0
	for reading in readings:
		bonus = 5.0 if reading in haystack else 0.0
		tight = compact(reading)
		if len(tight) >= 3 and tight in squeezed:
			bonus = max(bonus, 4.0)
		total = 0.0
		for word in _WORD.findall(reading):
			points = _word_score(word, targets)
			if not points:
				total = 0.0
				break
			total += points
		if total or bonus:
			best = max(best, total + bonus)
	return best
