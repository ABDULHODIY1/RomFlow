#!/usr/bin/env python3
"""Refreshes assets/manufacturers_uz.json from the public pages its prices
come from. Run once a day by .github/workflows/prices.yml.

Only prices that a page really shows are taken; a page that is down, has
changed its layout or shows a price far from yesterday's leaves the stored
price as it was. The catalog's version grows only when something changed,
so the apps download it only then.
"""
import datetime
import html
import json
import re
import sys
import urllib.request

CATALOG = 'assets/manufacturers_uz.json'
EKOPEN = 'https://ekopen.uz/alyuminiy-profil/'
GLASS = 'https://stroyka.uz/offers/steklo'
UNITS = 'https://stroyka.uz/offers/steklopakety'
CBU = 'https://cbu.uz/uz/arkhiv-kursov-valyut/json/USD/'
OPEN_RATE = 'https://open.er-api.com/v6/latest/USD'
BAR_M = 6  # Ekopen prices a 6 m bar

# Aldoks rows of the Ekopen price list → the catalog's price keys.
ALDOX_ROWS = {
    'frame': ('Алюминий Aldoks Рама - L', 'Aldoks rama L, 6 m tayoq'),
    'sash': ('Алюминий Aldoks Створка - Z', 'Aldoks qanot Z, 6 m tayoq'),
    'mullion': ('Алюминий Aldoks Импост - T', 'Aldoks impost T, 6 m tayoq'),
    'bead': ('Алюминий Aldoks Штапик Один.', 'Aldoks shtapik, 6 m tayoq'),
}
DOOR_ROW = ('Алюминий Aldoks Дверная Створка - Z',
            'Aldoks eshik qanoti Z/T, 6 m tayoq')
# Glass without a listing of its own: priced from 3.5 mm sheet glass by
# thickness and a factor for the kind.
ESTIMATED_GLASS = {
    'clear4': (4, 1.0), 'clear5': (5, 1.0), 'clear6': (6, 1.0),
    'toned4': (4, 1.5), 'matte4': (4, 1.6), 'lowe4': (4, 1.7),
}


def fetch(url):
    request = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (RomFlow price check)'})
    with urllib.request.urlopen(request, timeout=40) as response:
        return response.read().decode('utf-8', 'ignore')


def lines(page):
    page = re.sub(r'(?is)<(script|style|noscript|svg)[^>]*>.*?</\1>', '', page)
    page = re.sub(r'(?i)<(br|/p|/div|/tr|/li|/h\d|/td|/th)[^>]*>', '\n', page)
    page = html.unescape(re.sub(r'<[^>]+>', ' ', page))
    out = [re.sub(r'\s+', ' ', l).strip() for l in page.split('\n')]
    return [l for l in out if l]


def number(text):
    digits = re.sub(r'[^\d]', '', text)
    return int(digits) if digits else None


def ekopen_prices(rows):
    """{row name: so‘m for a 6 m bar}: a name is followed by 'N UZS'."""
    out = {}
    for i, line in enumerate(rows[:-1]):
        if rows[i + 1].endswith('UZS'):
            price = number(rows[i + 1])
            if price:
                out[line] = price
    return out


def stroyka_offers(rows):
    """[(offer name, price text)] of a Stroyka.uz listing page."""
    out = []
    for i, line in enumerate(rows):
        if line == 'Категория:' and i:
            for j in range(i + 1, min(i + 9, len(rows))):
                if rows[j] == 'Подробно':
                    out.append((rows[i - 1], rows[j - 1]))
                    break
    return out


def near(new, old, share=.4):
    """A new price counts only within [share] of the one it replaces."""
    return old is None or old <= 0 or abs(new - old) <= old * share


def main():
    catalog = json.load(open(CATALOG, encoding='utf-8'))
    before = json.dumps(catalog, sort_keys=True, ensure_ascii=False)
    today = datetime.date.today()
    seen = today.strftime('%Y-%m')
    notes = []

    rate = catalog['referenceUsdRate']
    try:
        try:
            fresh = float(json.loads(fetch(CBU))[0]['Rate'])
        except Exception as e:  # the bank's site is often slow from abroad
            notes.append(f'CBU: {e}')
            fresh = float(json.loads(fetch(OPEN_RATE))['rates']['UZS'])
        if near(fresh, rate, .2):
            rate = catalog['referenceUsdRate'] = round(fresh)
        else:
            notes.append(f'CBU rate {fresh} is far from {rate}: kept')
    except Exception as e:
        notes.append(f'dollar rate: {e}')

    systems = {s['id']: s for s in catalog['systems']}
    try:
        prices = ekopen_prices(lines(fetch(EKOPEN)))
        aldox = systems['akfa-aldox']
        market = {m['what']: m for m in aldox['market']}
        for key, (row, what) in list(ALDOX_ROWS.items()) + [(None, DOOR_ROW)]:
            som = prices.get(row)
            old = market.get(what, {}).get('price')
            if not som or not near(som, old):
                notes.append(f'Ekopen "{row}": {som} (was {old}), kept')
                som = old
            if not som:
                continue
            if what in market:
                if market[what]['price'] != som:
                    market[what].update(price=som, seen=seen)
            if key:
                aldox['usd'][key] = round(som / BAR_M / rate, 2)
    except Exception as e:
        notes.append(f'Ekopen: {e}')

    glass = {g['id']: g for g in catalog.get('glass', [])}
    try:
        for name, price in stroyka_offers(lines(fetch(GLASS))):
            low = name.lower()
            if 'листовое' in low and '3,5' in low and 'кв' in price:
                som = number(price)
                g = glass.get('clear35')
                if g and som and near(som, g.get('uzs')):
                    if g.get('uzs') != som:
                        g.update(uzs=som, seen=seen)
            if 'каленное' in low and '10 мм' in low and 'доллар' in price:
                glass.setdefault('_tempered', []).append(number(price))
        tempered = glass.pop('_tempered', [])
        g = glass.get('tempered10')
        if g and tempered:
            usd = round(sum(tempered) / len(tempered), 2)
            if near(usd, g['usd']) and usd != g['usd']:
                g.update(usd=usd, seen=seen)
    except Exception as e:
        notes.append(f'Stroyka glass: {e}')
    sheet = glass.get('clear35')
    if sheet and sheet.get('uzs'):
        sheet['usd'] = round(sheet['uzs'] / rate, 2)
        for gid, (mm, factor) in ESTIMATED_GLASS.items():
            if gid in glass:
                glass[gid]['usd'] = round(
                    sheet['uzs'] / 3.5 * mm * factor / rate, 2)
        catalog['common']['glass'] = glass['clear4']['usd']

    try:
        for name, price in stroyka_offers(lines(fetch(UNITS))):
            if name.strip() == 'Стеклопакеты' and 'кв' in price:
                som = number(price)
                for m in catalog['materialsMarket']:
                    if m['what'].startswith('Shishapaket') and som \
                            and near(som, m['price']) and m['price'] != som:
                        m.update(price=som, seen=seen)
    except Exception as e:
        notes.append(f'Stroyka units: {e}')

    for note in notes:
        print('note:', note)
    if json.dumps(catalog, sort_keys=True, ensure_ascii=False) == before:
        print('nothing changed')
        return 0
    catalog['version'] += 1
    catalog['date'] = today.isoformat()
    with open(CATALOG, 'w', encoding='utf-8') as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2)
        f.write('\n')
    print(f"catalog v{catalog['version']}, 1 $ = {rate}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
