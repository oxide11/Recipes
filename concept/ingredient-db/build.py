#!/usr/bin/env python3
"""Build the ingredient database from open sources.

Inputs (see README for where they come from):
  raw/official_sr28/*.txt      USDA National Nutrient Database for Standard Reference, official sr28asc.zip
                               (falls back to raw/USDA-SR28, a GitHub mirror of the same files)
  raw/official_sr28upd/*.txt   USDA's May 2016 revision of SR28 (sr28upd0516.zip), applied on top
  raw/official_srlegacy/*.json USDA SR Legacy, April 2018, FoodData Central JSON: replaces SR28 values food by food
  raw/official_fndds/*.json    USDA survey foods (FNDDS 2021-2023), FoodData Central JSON: foods as eaten
  raw/official_ff/**/food.csv  USDA Foundation Foods, FoodData Central CSV download (optional)
  raw/official_cnf2026/*.csv   Canadian Nutrient File 2026 (Health Canada), official download
                               (falls back to raw/cnfx, the 2015 edition, for French names only)
  raw/food-shelflife-db/...    USDA FSIS FoodKeeper shelf-life table
  overlay/curated.csv          our hand-kept list: canonical ingredients, aliases, which USDA food each maps to

Outputs (out/):
  foods.jsonl        every USDA food, cleaned: nutrition per 100 g, measures, density, tags
  ingredients.json   cooking ingredients: one record per ingredient, pointing at its foods
  ingredients.csv    the same, flat, for reading in a spreadsheet
  stats.json         counts and coverage, for the README and for checking a rebuild

Run: python3 -I build.py
"""
import csv, json, re, statistics, sys, os, unicodedata
from collections import defaultdict, OrderedDict

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, 'raw')
OUT = os.path.join(HERE, 'out')
os.makedirs(OUT, exist_ok=True)

# ---------------------------------------------------------------- USDA load
def sr(name):
    d = 'official_sr28' if os.path.isdir(os.path.join(RAW, 'official_sr28')) else 'USDA-SR28'   # official USDA zip first, mirror as fallback
    path = os.path.join(RAW, d, name + '.txt')
    with open(path, encoding='latin-1') as f:
        for line in f:
            line = line.rstrip('\r\n')
            if line:
                yield [c[1:-1] if len(c) >= 2 and c[0] == '~' and c[-1] == '~' else c for c in line.split('^')]

GROUPS = {r[0]: r[1] for r in sr('FD_GROUP')}

# nutrient number -> (field, unit, decimals)
NUTR = OrderedDict([
    ('208', ('energy_kcal', 'kcal', 0)), ('203', ('protein_g', 'g', 2)), ('204', ('fat_g', 'g', 2)),
    ('205', ('carbs_g', 'g', 2)), ('291', ('fibre_g', 'g', 1)), ('269', ('sugars_g', 'g', 2)),
    ('606', ('sat_fat_g', 'g', 2)), ('645', ('mono_fat_g', 'g', 2)), ('646', ('poly_fat_g', 'g', 2)),
    ('605', ('trans_fat_g', 'g', 2)), ('601', ('cholesterol_mg', 'mg', 0)), ('307', ('sodium_mg', 'mg', 0)),
    ('306', ('potassium_mg', 'mg', 0)), ('301', ('calcium_mg', 'mg', 0)), ('303', ('iron_mg', 'mg', 2)),
    ('304', ('magnesium_mg', 'mg', 0)), ('309', ('zinc_mg', 'mg', 2)), ('320', ('vitamin_a_mcg', 'mcg', 0)),
    ('401', ('vitamin_c_mg', 'mg', 1)), ('328', ('vitamin_d_mcg', 'mcg', 1)), ('323', ('vitamin_e_mg', 'mg', 2)),
    ('430', ('vitamin_k_mcg', 'mcg', 1)), ('418', ('vitamin_b12_mcg', 'mcg', 2)), ('435', ('folate_mcg', 'mcg', 0)),
    ('255', ('water_g', 'g', 1)), ('221', ('alcohol_g', 'g', 1)), ('262', ('caffeine_mg', 'mg', 0)),
])

nut = defaultdict(dict)
for r in sr('NUT_DATA'):
    if r[1] in NUTR:
        f, _, d = NUTR[r[1]]
        v = round(float(r[2]), d)
        nut[r[0]][f] = int(v) if d == 0 else v

weights = defaultdict(list)
for r in sr('WEIGHT'):
    try:
        weights[r[0]].append((float(r[2]), r[3].strip(), float(r[4]), 'usda'))
    except ValueError:
        pass

# ---------------------------------------------------------------- USDA SR28 revision of May 2016 (official update files)
UPD = os.path.join(RAW, 'official_sr28upd')
def upd(name):
    path = os.path.join(UPD, name + '.txt')
    if not os.path.exists(path): return
    with open(path, encoding='latin-1') as f:
        for line in f:
            line = line.rstrip('\r\n')
            if line:
                yield [c[1:-1] if len(c) >= 2 and c[0] == '~' and c[-1] == '~' else c for c in line.split('^')]
SR_FOODS = OrderedDict((r[0], r) for r in sr('FOOD_DES'))
upd_stats = dict(foods_changed=0, foods_added=0, nutrient_values_changed=0, nutrient_values_added=0, nutrient_values_deleted=0, measures_changed=0, measures_added=0, foods_touched=set())
if os.path.isdir(UPD):
    for r in upd('CHG_FOOD'):
        SR_FOODS[r[0]] = r; upd_stats['foods_changed'] += 1; upd_stats['foods_touched'].add(r[0])
    for r in upd('ADD_FOOD'):
        SR_FOODS[r[0]] = r; upd_stats['foods_added'] += 1; upd_stats['foods_touched'].add(r[0])
    for fname, k in (('CHG_NUTR', 'nutrient_values_changed'), ('ADD_NUTR', 'nutrient_values_added')):
        for r in upd(fname):
            upd_stats[k] += 1; upd_stats['foods_touched'].add(r[0])
            if r[1] in NUTR:
                f_, _, d_ = NUTR[r[1]]; v = round(float(r[2]), d_); nut[r[0]][f_] = int(v) if d_ == 0 else v
    for r in upd('DEL_NUTR'):
        upd_stats['nutrient_values_deleted'] += 1; upd_stats['foods_touched'].add(r[0])
        if r[1] in NUTR: nut[r[0]].pop(NUTR[r[1]][0], None)
    for fname, k in (('CHG_WGT', 'measures_changed'), ('ADD_WGT', 'measures_added')):
        for r in upd(fname):
            upd_stats[k] += 1; upd_stats['foods_touched'].add(r[0])
            try: seq, row = r[1], (float(r[2]), r[3].strip(), float(r[4]), 'usda')
            except ValueError: continue
            wl = weights[r[0]]
            idx = int(seq) - 1 if seq.isdigit() else len(wl)
            if fname == 'CHG_WGT' and 0 <= idx < len(wl): wl[idx] = row
            else: wl.append(row)
upd_stats['foods_touched'] = len(upd_stats['foods_touched'])

# ---------------------------------------------------------------- USDA SR Legacy (April 2018, final Standard Reference release)
import glob
def one_json(folder):
    hits = glob.glob(os.path.join(RAW, folder, '**', '*.json'), recursive=True)
    return hits[0] if hits else None
def fdc_nutrients(food):
    out = {}
    for fn in food.get('foodNutrients') or []:
        no = (fn.get('nutrient') or {}).get('number')
        if no in NUTR and fn.get('amount') is not None:
            f_, _, d_ = NUTR[no]; v = round(float(fn['amount']), d_); out[f_] = int(v) if d_ == 0 else v
    return out
legacy_stats = dict(foods=0, replaced_sr28=0, new_foods=0, sr28_foods_dropped=0, energy_changed=0)
sr_dropped, SRL = set(), one_json('official_srlegacy')
if SRL:
    GROUP_CODE = {v: k for k, v in GROUPS.items()}
    with open(SRL, encoding='utf-8') as f: legacy = json.load(f)['SRLegacyFoods']
    seen = set()
    for fd in legacy:
        ndb = str(fd['ndbNumber']).zfill(5); seen.add(ndb); legacy_stats['foods'] += 1
        n = fdc_nutrients(fd)
        if ndb in SR_FOODS:
            legacy_stats['replaced_sr28'] += 1
            row = list(SR_FOODS[ndb]); row[2] = fd['description'].strip(); SR_FOODS[ndb] = row
            if n.get('energy_kcal') != nut.get(ndb, {}).get('energy_kcal'): legacy_stats['energy_changed'] += 1
        else:
            legacy_stats['new_foods'] += 1
            grp = GROUP_CODE.get((fd.get('foodCategory') or {}).get('description', ''), '')
            SR_FOODS[ndb] = [ndb, grp, fd['description'].strip(), '', '', '', '', '', '', '', '', '', '', '']
        if n: nut[ndb] = n
        ports = []
        for p in sorted(fd.get('foodPortions') or [], key=lambda p: p.get('sequenceNumber') or 0):
            unit = (p.get('measureUnit') or {}).get('name', '')
            desc = (p.get('modifier') or '').strip() if unit in ('undetermined', '') else (unit + (', ' + p['modifier'].strip() if p.get('modifier') else ''))
            if desc and p.get('gramWeight'): ports.append((float(p.get('amount') or p.get('value') or 1), desc, float(p['gramWeight']), 'usda'))
        if ports: weights[ndb] = ports
    sr_dropped = set(SR_FOODS) - seen
    legacy_stats['sr28_foods_dropped'] = len(sr_dropped)
    del legacy

# ---------------------------------------------------------------- measures
ML = {'cup': 236.588, 'tbsp': 14.787, 'tsp': 4.929, 'fl oz': 29.574, 'quart': 946.353, 'pint': 473.176,
      'ml': 1.0, 'liter': 1000.0, 'gallon': 3785.41}
VOL_RE = re.compile(r'^(cups?|tbsp|tablespoons?|tsp|teaspoons?|fl\.? ?oz|quarts?|pints?|ml|liters?|gallons?)\b[ ,]*(.*)$', re.I)
VOL_CANON = {'cups': 'cup', 'tablespoon': 'tbsp', 'tablespoons': 'tbsp', 'teaspoon': 'tsp', 'teaspoons': 'tsp',
             'fl oz': 'fl oz', 'fl. oz': 'fl oz', 'floz': 'fl oz', 'fl.oz': 'fl oz', 'quarts': 'quart', 'pints': 'pint',
             'liters': 'liter', 'gallons': 'gallon'}
MASS_RE = re.compile(r'^(oz|lb|g|kg|pound|ounce)s?\b', re.I)
COUNT_WORDS = ['extra large', 'jumbo', 'large', 'medium', 'small', 'clove', 'slice', 'stalk', 'sprig', 'leaf', 'leaves',
               'head', 'ear', 'bunch', 'stick', 'pat', 'can', 'fruit', 'egg', 'piece', 'strip', 'link', 'patty',
               'fillet', 'breast', 'thigh', 'drumstick', 'wing', 'leg', 'chop', 'steak', 'spear', 'floweret', 'pod',
               'pepper', 'tomato', 'potato', 'onion', 'carrot', 'berry', 'cherry', 'olive', 'nut', 'kernel', 'bulb',
               'root', 'cube', 'square', 'bar', 'package', 'container', 'envelope', 'packet', 'bottle', 'jar', 'serving',
               'unit', 'item', 'whole', 'half', 'ring', 'wedge', 'rib', 'rack', 'roast', 'bird', 'shrimp', 'oyster',
               'clam', 'scallop', 'mussel', 'lobster', 'crab', 'anchovy', 'sardine', 'tortilla', 'cracker', 'cookie',
               'muffin', 'roll', 'bagel', 'bun', 'loaf', 'pie', 'cake', 'shell', 'crust', 'sheet', 'pancake', 'waffle']

def clean_form(s):
    s = re.sub(r'\(.*?\)', '', s).strip(' ,')
    return re.sub(r'\s+', ' ', s).lower()

def parse_measures(ndb):
    """-> (portions list, density g/ml or None, density basis, unit weights dict)"""
    portions, dens, units = [], [], {}
    for amount, desc, grams, src in weights.get(ndb, []):
        if amount <= 0 or grams <= 0:
            continue
        d = desc.strip()
        p = {'amount': amount if amount != int(amount) else int(amount), 'measure': d, 'grams': round(grams, 2)}
        if src != 'usda': p['source'] = src
        m = VOL_RE.match(d)
        if m:
            u = m.group(1).lower().replace('.', '')
            u = VOL_CANON.get(u, u)
            form = clean_form(m.group(2))
            p['kind'] = 'volume'; p['unit'] = u
            if form: p['form'] = form
            gml = grams / (amount * ML[u])
            p['g_per_ml'] = round(gml, 3)
            if 0.03 < gml < 3.0:
                dens.append((form, gml, u))
        elif MASS_RE.match(d):
            p['kind'] = 'mass'
        else:
            p['kind'] = 'count'
            low = clean_form(d)
            for w in COUNT_WORDS:
                if re.search(r'\b' + w + r's?\b', low):
                    key = low if len(low) <= 28 else w
                    units.setdefault(key, round(grams / amount, 1))
                    p['unit'] = w
                    break
        portions.append(p)
    density, basis = None, None
    if dens:
        plain = [g for f, g, u in dens if not f]
        cups = [g for f, g, u in dens if u == 'cup']
        if plain:
            density, basis = statistics.median(plain), 'plain measure'
        elif cups:
            density, basis = statistics.median(cups), 'cup, ' + next(f for f, g, u in dens if u == 'cup')
        else:
            density, basis = statistics.median([g for f, g, u in dens]), dens[0][0] or 'measure'
        density = round(density, 3)
    return portions, density, basis, units

# ---------------------------------------------------------------- classification
STATE_WORDS = [
    ('cooked', r'\b(cooked|boiled|roasted|baked|braised|grilled|fried|pan-fried|stir-fried|steamed|saut[eé]ed|stewed|microwaved|broiled|simmered|toasted|poached|scrambled|rotisserie|heated|prepared|scalded|blanched)\b'),
    ('canned', r'\b(canned|bottled|jarred)\b'),
    ('frozen', r'\b(frozen)\b'),
    ('dried', r'\b(dried|dehydrated|dry|freeze-dried|powder|powdered|flakes?)\b'),
    ('pickled', r'\b(pickled|sour|brined|marinated)\b'),
    ('cured', r'\b(cured|smoked|salted|kippered)\b'),
    ('raw', r'\b(raw|fresh|uncooked|unprepared|unheated)\b'),
]
def state_of(desc):
    low = desc.lower()
    hits = [name for name, rx in STATE_WORDS if re.search(rx, low)]
    # the last-applied process wins for the label; keep the full list too
    order = ['cooked', 'canned', 'frozen', 'pickled', 'cured', 'dried', 'raw']
    for o in order:
        if o in hits:
            return o, hits
    return None, hits

BRAND_RE = re.compile(r"\b[A-Z][A-Z'&\.\-]{2,}\b")
NOT_BRAND = {'USDA', 'UHT', 'NFS', 'NS', 'DHA', 'ARA', 'USA', 'RTE', 'RTS', 'RTF', 'RTB', 'RTC', 'RTH', 'RTD', 'IQF', 'BBQ', 'BHA', 'BHT', 'TVP', 'MSG', 'CSFP', 'FNS', 'CACFP', 'NSLP', 'WIC', 'LFS', 'PUFA', 'MUFA', 'CLA', 'STPP', 'APHIS', 'HFCS', 'XXX', 'III', 'TFE'}
PREPARED_GROUPS = {'2100': 'prepared', '2200': 'prepared', '3600': 'prepared', '0300': 'baby', '2500': 'prepared'}

def kind_of(grp, desc, manuf):
    if grp in PREPARED_GROUPS:
        return PREPARED_GROUPS[grp]
    if re.match(r'USDA Commodity', desc) or re.search(r'\bindustrial\b|\bfood service\b|\binstitutional\b', desc, re.I):
        return 'institutional'
    brands = [b for b in BRAND_RE.findall(desc) if b.strip(".'") not in NOT_BRAND]
    if manuf or brands:
        return 'branded'
    low = desc.lower()
    if grp == '0600' and low.startswith('soup,') and not re.search(r'\b(stock|broth|bouillon|consomme)\b', low):
        return 'prepared'
    if grp == '0800':
        return 'ingredient' if low.startswith('cereals,') else 'prepared'
    if grp == '1900' and re.match(r'(candies|ice creams|frozen|desserts|puddings|gelatin desserts|frostings|snacks|pie fillings|toppings|frozen novelties|fruit butters|ice cream)', low):
        return 'prepared'
    if grp == '3500':
        return 'regional'
    return 'ingredient'

def aisle_of(grp, desc, state):
    low = desc.lower()
    if grp == '0100': return 'Dairy and eggs'
    if grp == '0200': return 'Produce' if re.search(r'\bfresh\b', low) else 'Pantry'
    if grp == '0400': return 'Dairy and eggs' if re.match(r'(margarine|butter)', low) else 'Pantry'
    if grp in ('0500', '0700', '1000', '1300', '1700', '1500'):
        return 'Canned' if state == 'canned' else 'Frozen' if state == 'frozen' and grp == '1500' else 'Meat and seafood'
    if grp in ('0900', '1100'):
        if state == 'canned': return 'Canned'
        if state == 'frozen': return 'Frozen'
        if state == 'dried': return 'Dry goods'
        if re.search(r'\b(juice|nectar|sauce|paste|puree|catsup|ketchup|pickle|relish)\b', low): return 'Pantry'
        return 'Produce'
    if grp == '1200': return 'Dry goods'
    if grp == '1600':
        if state == 'canned': return 'Canned'
        if re.search(r'\b(tofu|tempeh|soymilk|miso|hummus)\b', low): return 'Dairy and eggs'
        if re.search(r'\b(sauce|butter)\b', low): return 'Pantry'
        return 'Dry goods'
    if grp in ('2000', '0800'): return 'Dry goods'
    if grp == '1800': return 'Bakery'
    if grp == '0600': return 'Canned'
    return 'Pantry'

def has(rx, s): return re.search(rx, s) is not None

def allergens_of(grp, desc):
    """Rule-based. A starting point to review, not a safety guarantee."""
    low = ' ' + desc.lower() + ' '
    a = set()
    plant_milk = has(r'\b(coconut|almond|soy|rice|oat|cashew|hemp)[ -]?milk\b|\bsoymilk\b|milk substitutes', low)
    if grp == '0100' and not low.strip().startswith('egg'):
        if not plant_milk: a.add('milk')
    if has(r'\b(milk|cheese|butter|cream|yogurt|yoghurt|whey|casein|ghee|buttermilk|custard|kefir)\b', low) and not plant_milk \
       and not has(r'\b(peanut|almond|cashew|nut|seed|sesame|sunflower|apple|cocoa|shea|fruit) butter\b|cream of tartar|butter ?beans|butterhead|butternut|butterbur|butterfish|buttercup|cream substitute|non-?dairy|cocoa butter|creamed coconut|coconut cream|cream style|cream-style', low):
        a.add('milk')
    if has(r'\beggs?\b|\beggnog\b|\bmayonnaise\b', low) and not has(r'egg substitute|eggplant|eggless', low): a.add('egg')
    if grp == '1500':
        if has(r'^ ?(crustaceans|mollusks)', low) or has(r'\b(shrimp|crab|lobster|crayfish|clam|oyster|mussel|scallop|squid|octopus|abalone|whelk|cuttlefish|snail|conch)\b', low): a.add('shellfish')
        else: a.add('fish')
    if has(r'\b(anchov|fish sauce|worcestershire|caviar|roe|surimi|fish oil|cod liver)\b', low): a.add('fish')
    if has(r'\b(shrimp|crab|lobster|oyster|clam) ', low) and grp != '1500': a.add('shellfish')
    if grp == '1200' and has(r'^ ?nuts,', low) and not has(r'coconut|ginkgo|chestnut', low): a.add('tree nuts')
    if has(r'\b(almond|walnut|pecan|cashew|pistachio|hazelnut|filbert|macadamia|brazil ?nut|pine nut|pili ?nut|marzipan|praline)s?\b', low): a.add('tree nuts')
    if has(r'\bpeanuts?\b', low): a.add('peanuts')
    if has(r'\b(wheat|barley|rye|triticale|spelt|kamut|semolina|couscous|bulgur|farro|seitan|durum|malt|malted)\b', low) and not has(r'buckwheat|gluten[- ]free', low): a.add('wheat or gluten')
    if (grp == '1800' or has(r'\b(pasta|macaroni|noodles?|spaghetti|bread|breadcrumbs?|crackers?|croutons?|flour tortilla|pie crust|pastry|phyllo|wonton|biscuit|pancake|waffle|pretzel|cake|cookie|muffin|bagel|pita)\b', low)) \
       and not has(r'gluten[- ]free|rice noodles?|corn tortilla|rice flour|\bcorn(meal)?\b.*(bread|muffin)?$|buckwheat|rice cake|corn pasta|rice pasta|cellophane|mung', low):
        a.add('wheat or gluten')
    if has(r'\b(soy|soya|soybeans?|soymilk|tofu|tempeh|miso|edamame|natto|tamari|shoyu|teriyaki)\b', low): a.add('soy')
    if has(r'\b(sesame|tahini)\b', low): a.add('sesame')
    if has(r'\bmustard\b', low) and not has(r'mustard greens|mustard spinach', low): a.add('mustard')
    if has(r'\b(wine|sulfite|sulphite|sulfured|sulphured)\b', low): a.add('sulphites')
    return sorted(a)

ANIMAL = {'0500', '0700', '1000', '1300', '1500', '1700'}
def diet_of(grp, desc):
    low = desc.lower()
    meat = grp in ANIMAL or has(r'\b(beef|pork|chicken|turkey|lamb|veal|bacon|ham|sausage|fish|anchov|shrimp|crab|clam|oyster|lard|tallow|gelatin|meat|suet|bone|duck|goose|salami|pepperoni|oyster sauce|fish sauce|worcestershire)\b', low) \
        and not has(r'meatless|vegetarian|imitation|meat substitute|bacon bits, meatless', low)
    if meat: return 'contains meat or fish'
    if grp == '0100' or has(r'\b(milk|cheese|butter|cream|yogurt|whey|egg|eggs|honey|casein|ghee|mayonnaise)\b', low) and not has(r'(coconut|almond|soy|rice|oat) ?milk|peanut butter|nut butter|cocoa butter|cream of tartar|eggplant|non-?dairy|butter ?beans|butternut', low):
        return 'vegetarian'
    return 'vegan'

# ---------------------------------------------------------------- Canadian Nutrient File (French names)
def norm(s):
    s = unicodedata.normalize('NFKD', s).encode('ascii', 'ignore').decode().lower()
    s = re.sub(r'[^a-z0-9% ]+', ' ', s)
    return ' '.join(s.split())

cnf_fr, cnf_tokens = {}, {}
try:
    with open(os.path.join(RAW, 'cnfx', 'FOOD NAME.csv'), encoding='latin-1', newline='') as f:
        for row in csv.DictReader(f):
            en, fr = row['FoodDescription'].strip(), row['FoodDescriptionF'].strip()
            if en and fr:
                cnf_fr[norm(en)] = (fr, row['FoodID'])
                cnf_tokens[frozenset(norm(en).split())] = (fr, row['FoodID'])
except FileNotFoundError:
    print('note: Canadian Nutrient File not found, skipping French names', file=sys.stderr)

cnf_by_first = defaultdict(list)
for toks, val in cnf_tokens.items():
    pass
for n_, val in cnf_fr.items():
    t = n_.split()
    if t: cnf_by_first[singular_early(t[0]) if False else t[0][:5]].append((frozenset(t), val))

def french(desc):
    n = norm(desc)
    if n in cnf_fr: return cnf_fr[n]
    toks = frozenset(n.split())
    hit = cnf_tokens.get(toks)
    if hit: return hit
    best, bv = 0.0, None
    for ct, val in cnf_by_first.get(n.split()[0][:5] if n else '', []):
        j = len(toks & ct) / float(len(toks | ct))
        if j > best: best, bv = j, val
    return bv if best >= 0.8 else None

# ---------------------------------------------------------------- FoodKeeper (shelf life)
DAYS = {'days': 1, 'day': 1, 'weeks': 7, 'week': 7, 'months': 30, 'month': 30, 'years': 365, 'year': 365}
keeper = {}
try:
    with open(os.path.join(RAW, 'food-shelflife-db', 'lib', 'seeds', 'ingredients.csv'), encoding='utf-8', newline='') as f:
        for row in csv.DictReader(f):
            def span(prefixes):
                for p in prefixes:
                    lo, hi, m = row.get(p + '_Min', ''), row.get(p + '_Max', ''), (row.get(p + '_Metric', '') or '').strip().lower()
                    if lo and hi and m in DAYS:
                        try: return [int(float(lo) * DAYS[m]), int(float(hi) * DAYS[m])]
                        except ValueError: pass
                return None
            rec = {'pantry_days': span(['Pantry', 'DOP_Pantry']), 'fridge_days': span(['Refrigerate', 'DOP_Refrigerate']),
                   'freezer_days': span(['Freeze', 'DOP_Freeze']), 'opened_fridge_days': span(['Refrigerate_After_Opening']),
                   'source_name': (row['Name'] + (' ' + row['Name_subtitle'] if row.get('Name_subtitle') else '')).strip()}
            if not any(rec[k] for k in ('pantry_days', 'fridge_days', 'freezer_days')): continue
            names = [row['Name']] + [k for k in (row.get('Keywords') or '').split(',')]
            for nm in names:
                k = norm(nm)
                if k and k not in keeper: keeper[k] = rec
except FileNotFoundError:
    print('note: FoodKeeper table not found, skipping shelf life', file=sys.stderr)

def singular(w):
    if w.endswith('ies') and len(w) > 4: return w[:-3] + 'y'
    if w.endswith('oes') and len(w) > 4: return w[:-2]
    if w.endswith('ses') or w.endswith('ss') or w.endswith('us'): return w
    if w.endswith('s') and len(w) > 3: return w[:-1]
    return w
def skey(name): return ' '.join(singular(w) for w in norm(name).split())

def shelf(names):
    for nm in names:
        for k in (norm(nm), skey(nm)):
            if k in keeper: return keeper[k]
        for kk, rec in keeper.items():
            if skey(kk) == skey(nm): return rec
    return None

# ---------------------------------------------------------------- Canadian Nutrient File 2026 (official): second source
CNF = os.path.join(RAW, 'official_cnf2026')
cnf_link, cnf_only, cnf_nut, cnf_yield, cnf_refuse = {}, [], defaultdict(dict), defaultdict(list), {}
CNF_MEAS = re.compile(r'^(\d+(?:[.,]\d+)?)\s*(ml|l|tsp|tbsp|cup|cups|g|kg)?\b\s*(.*)$', re.I)
def cnf_rows(name):
    with open(os.path.join(CNF, name), encoding='utf-8-sig', newline='') as f:
        for row in csv.DictReader(f): yield row
if os.path.isdir(CNF):
    sr_ids = set(SR_FOODS)
    mname = {r['Measure_Code']: r['Measure_Description_and_Unit_EN'].strip() for r in cnf_rows('Measure_Name.csv')}
    cnf_foods = {r['Food_Code']: r for r in cnf_rows('Food_Name.csv')}
    target = {}                                   # CNF food code -> key in our foods table
    for code, r in cnf_foods.items():
        ndb = r['USDA_NDB_Code'].strip().zfill(5) if r['USDA_NDB_Code'].strip() else ''
        if ndb in sr_ids:
            target[code] = ndb
            cnf_link.setdefault(ndb, r)           # first Canadian food linked to this USDA food
        else:
            target[code] = 'cnf:' + code
            cnf_only.append(r)
    for r in cnf_rows('Measure_Weight_Conversion.csv'):
        code, kind, desc = r['Food_Code'], r['Measure_Type_Code'], mname.get(r['Measure_Code'], '')
        if code not in target or not desc: continue
        try: val = float(r['Measure_Weight_Conversion'])
        except ValueError: continue
        key = target[code]
        if kind == '3': cnf_refuse[key] = (val, desc)
        elif kind == '9': cnf_yield[key].append({'description': desc, 'value': round(val, 2)})
        elif kind == '6' and val > 0:
            if not key.startswith('cnf:') and cnf_link.get(key, {}).get('Food_Code') != code: continue
            m = CNF_MEAS.match(desc)
            if not m: continue
            amount = float(m.group(1).replace(',', '.')); unit = (m.group(2) or '').lower(); rest = m.group(3).strip(' ,')
            if unit in ('g', 'kg') or amount <= 0: continue
            if unit: d = {'l': 'liter', 'cups': 'cup'}.get(unit, unit) + (', ' + rest if rest else '')
            else: d = rest or 'item'
            weights[key].append((amount, d, val, 'cnf'))
    wanted = set(NUTR)
    for r in cnf_rows('Nutrient_Amount.csv'):
        if r['Nutrient_Code'] in wanted and target.get(r['Food_Code'], '').startswith('cnf:'):
            f_, _, d_ = NUTR[r['Nutrient_Code']]
            try: v = round(float(r['Nutrient_Amount']), d_)
            except ValueError: continue
            cnf_nut[target[r['Food_Code']]][f_] = int(v) if d_ == 0 else v

# ---------------------------------------------------------------- USDA Foundation Foods (FoodData Central CSV layout)
ff_foods, ff_nut, ff_ndb = [], defaultdict(dict), {}
def ff_dir():
    base = os.path.join(RAW, 'official_ff')
    if not os.path.isdir(base): return None
    for root, dirs, files in os.walk(base):
        if 'food.csv' in files and 'food_nutrient.csv' in files: return root
    return None
FF = ff_dir()
if FF:
    def ff_rows(name):
        with open(os.path.join(FF, name), encoding='utf-8', newline='') as f:
            for row in csv.DictReader(f): yield row
    cat = {r['id']: r['code'] for r in ff_rows('food_category.csv')}
    ffood = {r['fdc_id']: r for r in ff_rows('food.csv') if r['data_type'] == 'foundation_food'}
    nbr = {r['id']: r['nutrient_nbr'] for r in ff_rows('nutrient.csv')}
    # same field, several possible nutrient numbers; first listed wins
    ALT = {'208': ['208', '958', '957'], '269': ['269', '269.3'], '291': ['291', '293'], '435': ['435', '417']}
    order = {}
    for sr_no, (f_, _, d_) in NUTR.items():
        for rank, n_ in enumerate(ALT.get(sr_no, [sr_no])): order[n_] = (f_, d_, rank)
    best_rank = defaultdict(dict)
    for r in ff_rows('food_nutrient.csv'):
        if r['fdc_id'] not in ffood: continue
        o = order.get(nbr.get(r['nutrient_id'], ''))
        if not o or r['amount'] == '': continue
        f_, d_, rank = o; key = 'fdc:' + r['fdc_id']
        if f_ in best_rank[key] and best_rank[key][f_] <= rank: continue
        v = round(float(r['amount']), d_); ff_nut[key][f_] = int(v) if d_ == 0 else v; best_rank[key][f_] = rank
    mu = {r['id']: r['name'] for r in ff_rows('measure_unit.csv')}
    UN = {'tablespoon': 'tbsp', 'teaspoon': 'tsp'}
    for r in ff_rows('food_portion.csv'):
        if r['fdc_id'] not in ffood: continue
        try: amount, grams = float(r['amount'] or 1), float(r['gram_weight'])
        except ValueError: continue
        unit = mu.get(r['measure_unit_id'], ''); unit = '' if unit in ('undetermined', '') else UN.get(unit, unit)
        extra = ', '.join(x for x in (r['portion_description'].strip(), r['modifier'].strip()) if x)
        desc = (unit + (', ' + extra if extra else '')) if unit else (extra or 'item')
        weights['fdc:' + r['fdc_id']].append((amount, desc, grams, 'usda'))
    for r in ff_rows('foundation_food.csv'):
        if r['fdc_id'] in ffood and r['NDB_number'].strip(): ff_ndb['fdc:' + r['fdc_id']] = r['NDB_number'].strip().zfill(5)
    ff_foods = [(('fdc:' + i), r['description'].strip(), cat.get(r['food_category_id'], ''), r['publication_date']) for i, r in ffood.items()]

# ---------------------------------------------------------------- foods table
foods = OrderedDict()
def add_food(key, grp, long_desc, manuf, sci, refuse, refuse_note, n, source):
    state, states = state_of(long_desc)
    portions, density, basis, units = parse_measures(key)
    rec = OrderedDict(id=key if ':' in key else 'usda:' + key, source=source, description=long_desc, group=GROUPS.get(grp, grp),
                      kind=kind_of(grp, long_desc, manuf), state=state, aisle=aisle_of(grp, long_desc, state))
    if sci: rec['scientific_name'] = sci
    link = cnf_link.get(key)
    if source == 'cnf':
        link = None
    if link:
        rec['description_fr'] = link['Food_Description_FR'].strip(); rec['cnf_food_code'] = int(link['Food_Code'])
        alt = [a.strip() for a in re.split(r'[,;]', link['Alternate_Description_EN']) if a.strip()]
        if alt: rec['alt_names'] = alt
    elif source == 'usda' and not os.path.isdir(CNF):
        fr = french(long_desc)
        if fr: rec['description_fr'] = fr[0]; rec['cnf_food_code'] = int(fr[1])
    if refuse not in ('', '0', None):
        try: rec['refuse_pct'] = int(float(refuse)); rec['refuse_note'] = refuse_note
        except ValueError: pass
    rec['per_100g'] = OrderedDict((f, n[f]) for f, _, _ in NUTR.values() if f in n)
    if density: rec['density_g_per_ml'] = density; rec['density_basis'] = basis
    if units: rec['unit_weights_g'] = units
    rec['measures'] = portions
    if cnf_yield.get(key): rec['yields'] = cnf_yield[key]
    rec['allergens'] = allergens_of(grp, long_desc)
    rec['diet'] = diet_of(grp, long_desc)
    foods[key] = rec
    return rec

for r in SR_FOODS.values():
    add_food(r[0], r[1], r[2].strip(), r[5].strip(), r[9].strip(), r[8], r[7].strip(), nut.get(r[0], {}), 'usda')
for r in cnf_only:
    key = 'cnf:' + r['Food_Code']
    if 'energy_kcal' not in cnf_nut.get(key, {}): continue
    grp = '%02d00' % int(r['CNF_Food_Group_Code'])
    ref = cnf_refuse.get(key)
    rec = add_food(key, grp, r['Food_Description_EN'].strip(), '', r['ScientificName'].strip(), ref[0] if ref else None, ref[1] if ref else '', cnf_nut[key], 'cnf')
    rec['description_fr'] = r['Food_Description_FR'].strip(); rec['cnf_food_code'] = int(r['Food_Code'])
    alt = [a.strip() for a in re.split(r'[,;]', r['Alternate_Description_EN']) if a.strip()]
    if alt: rec['alt_names'] = alt
    if r['USDA_NDB_Code'].strip(): rec['usda_ndb_not_in_sr28'] = r['USDA_NDB_Code'].strip()
for ndb in sr_dropped:
    if ndb in foods: foods[ndb]['dropped_in_sr_legacy'] = True

# ---------------------------------------------------------------- USDA survey foods (FNDDS): foods as eaten, with consumer wording
survey_stats = dict(foods=0, single_ingredient=0)
FND = one_json('official_fndds')
if FND:
    with open(FND, encoding='utf-8') as f: survey = json.load(f)['SurveyFoods']
    PD = re.compile(r'^(\d+(?:\.\d+)?(?:/\d+)?)\s+(.*)$')
    for fd in survey:
        n = fdc_nutrients(fd)
        if 'energy_kcal' not in n: continue
        key = 'fndds:' + str(fd['foodCode'])
        for p in fd.get('foodPortions') or []:
            m = PD.match((p.get('portionDescription') or '').strip())
            if not m or not p.get('gramWeight'): continue
            a = m.group(1)
            amount = float(a.split('/')[0]) / float(a.split('/')[1]) if '/' in a else float(a)
            if amount > 0: weights[key].append((amount, m.group(2).strip(), float(p['gramWeight']), 'usda'))
        state, _ = state_of(fd['description'])
        portions, density, basis, units = parse_measures(key)
        rec = OrderedDict(id=key, source='usda-survey', description=fd['description'].strip(),
                          group=(fd.get('wweiaFoodCategory') or {}).get('wweiaFoodCategoryDescription', ''), kind='survey', state=state, aisle=None)
        rec['per_100g'] = OrderedDict((f_, n[f_]) for f_, _, _ in NUTR.values() if f_ in n)
        if density: rec['density_g_per_ml'] = density; rec['density_basis'] = basis
        if units: rec['unit_weights_g'] = units
        rec['measures'] = portions
        made = []
        for i in sorted(fd.get('inputFoods') or [], key=lambda i: i.get('sequenceNumber') or 0):
            code = str(i.get('ingredientCode') or '')
            ref = 'usda:' + code.zfill(5) if code.zfill(5) in foods else ('fndds:' + code if len(code) == 8 else None)
            made.append(OrderedDict(food=ref, description=(i.get('ingredientDescription') or '').strip(), grams=i.get('ingredientWeight')))
        if made: rec['made_from'] = made
        rec['allergens'] = []; rec['diet'] = 'unknown'
        foods[key] = rec
        survey_stats['foods'] += 1
        if len(made) == 1 and made[0]['food'] and made[0]['food'].startswith('usda:'):
            survey_stats['single_ingredient'] += 1
            foods[made[0]['food'][5:]].setdefault('survey_names', []).append(rec['description'])
    del survey

for key, desc, grp, pub in ff_foods:
    if 'energy_kcal' not in ff_nut.get(key, {}): continue
    rec = add_food(key, grp, desc, '', '', None, '', ff_nut[key], 'usda-foundation')
    rec['published'] = pub
    ndb = ff_ndb.get(key)
    if ndb in foods:
        rec['same_food_in_sr28'] = 'usda:' + ndb
        foods[ndb]['newer_lab_data'] = key
        if foods[ndb].get('description_fr'): rec['description_fr'] = foods[ndb]['description_fr']

# ---------------------------------------------------------------- ingredient concepts (automatic)
GENERIC_TEMPLATES = {
    'cheese': '{1} cheese', 'cheese food': None, 'spices': '{1}', 'nuts': '{1}', 'seeds': '{1}', 'oil': '{1} oil',
    'fish': '{1}', 'crustaceans': '{1}', 'mollusks': '{1}', 'beans': '{1} beans', 'lettuce': '{1} lettuce',
    'squash': '{1} squash', 'peppers': '{1} peppers', 'mushrooms': '{1} mushrooms', 'rice': '{1} rice',
    'wheat flour': '{1} wheat flour', 'vinegar': '{1} vinegar', 'sauce': '{1} sauce', 'syrups': '{1} syrup',
    'sugars': '{1} sugar', 'milk': '{1} milk', 'cream': '{1} cream', 'yogurt': '{1} yogurt', 'bread': '{1} bread',
    'cereals': '{1}', 'vegetable oil': '{1} oil', 'alcoholic beverage': '{1}', 'beverages': '{1}', 'leavening agents': '{1}',
    'sweeteners': '{1}', 'salad dressing': '{1} dressing', 'soup': '{1}', 'game meat': '{1}', 'peas': '{1} peas',
    'potatoes': None, 'tomatoes': None, 'onions': None, 'cabbage': '{1} cabbage', 'melons': '{1} melon', 'pasta': None,
    'noodles': '{1} noodles', 'flour': None, 'corn flour': None, 'tomato products': '{2}', 'lentils': None,
    'pork': None, 'beef': None, 'lamb': None, 'veal': None, 'chicken': None, 'turkey': None, 'duck': None,
    'fat': '{1} fat', 'shortening': None, 'margarine': None, 'egg': None, 'cocoa': None, 'chocolate': None,
    'baking chocolate': '{1} baking chocolate', 'candies': None, 'seaweed': '{1} seaweed', 'soybeans': None,
    'jams and preserves': None, 'jellies': None, 'pickles': '{1} pickles', 'olives': None, 'pie crust': None,
}
SKIP_SEG = re.compile(r'^(raw|fresh|cooked|boiled|drained|canned|frozen|dried|unprepared|prepared|unenriched|enriched|'
                      r'with salt|without salt|salted|unsalted|mature seeds|immature seeds|all varieties|all types|'
                      r'commercial|regular|whole|domestic|farmed|wild|mixed species|broilers or fryers|roasting|stewing|'
                      r'separable lean and fat|separable lean only|all grades|choice|select|prime|composite of trimmed retail cuts|'
                      r'meat only|meat and skin|year round average|includes .*|solids and liquids|fluid|ns as to .*|.*trimmed to.*)$', re.I)
MEAT_HEADS = {'beef', 'pork', 'lamb', 'veal', 'chicken', 'turkey', 'duck', 'goose', 'game meat'}
CUT_WORDS = r'(ground|chuck|brisket|rib|ribeye|short ?ribs?|loin|tenderloin|sirloin|round|flank|shank|shoulder|leg|breast|thigh|drumstick|wing|liver|heart|tongue|kidney|giblets|belly|bacon|ham|chop|cutlet|stew meat|tri-tip|top sirloin|bottom round|eye of round|rump|plate|skirt|porterhouse|t-bone|spareribs|backribs|butt|picnic|jowl|feet|tail|tripe|sweetbread|brain|dark meat|light meat|variety meats)'

def concept_name(desc, grp):
    segs = [s.strip() for s in re.sub(r'\(.*?\)', '', desc).split(',') if s.strip()]
    head = segs[0].lower()
    rest = [s for s in segs[1:] if not SKIP_SEG.match(s)]
    if head == 'game meat' and len(segs) > 1:
        return segs[1].lower()
    if head in MEAT_HEADS:
        for s in segs[1:]:
            m = re.search(r'\b' + CUT_WORDS + r'\b', s.lower())
            if m:
                cut = m.group(1)
                return ('ground ' + head) if cut == 'ground' else (head + ' ' + cut)
        return head
    tpl = GENERIC_TEMPLATES.get(head, '__plain__')
    if tpl == '__plain__' or tpl is None or not rest:
        return head
    one = rest[0].lower()
    two = rest[1].lower() if len(rest) > 1 else one
    name = tpl.replace('{1}', one).replace('{2}', two)
    name = re.sub(r'\b(\w+) \1\b', r'\1', name)          # "sesame seeds seeds"
    for w in ('cheese', 'oil', 'beans', 'sauce', 'milk', 'cream', 'rice', 'bread', 'sugar', 'syrup', 'vinegar', 'lettuce', 'squash', 'peppers', 'mushrooms', 'peas', 'noodles', 'dressing'):
        name = re.sub(r'\b%s\b(.*)\b%s\b' % (w, w), r'%s\1' % w, name).strip()
    return ' '.join(name.split())

def variant_score(rec):
    s = 0
    st = rec['state']
    if st in (None, 'raw'): s += 30
    if st == 'cooked': s -= 20
    if st in ('canned', 'frozen', 'pickled', 'cured'): s -= 10
    if rec.get('density_g_per_ml'): s += 4
    if rec.get('unit_weights_g'): s += 3
    if len(rec['per_100g']) >= 15: s += 3
    low = rec['description'].lower()
    if rec.get('dropped_in_sr_legacy'): s -= 6
    if re.search(r'\b(low ?fat|nonfat|fat free|reduced|lite|light|imitation|substitute|low sodium|with added|fortified|unsalted|without salt|sweetened|flavored|diet)\b', low): s -= 8
    s -= len(rec['description']) / 12.0
    return s

concepts = defaultdict(list)
for ndb, rec in foods.items():
    if rec['kind'] != 'ingredient': continue
    grp = [k for k, v in GROUPS.items() if v == rec['group']][0]
    concepts[concept_name(rec['description'], grp)].append(ndb)

# ---------------------------------------------------------------- curated overlay
def find_food(expr):
    """expr: 'usda:01001' or words that must all appear / '!word' must not. Picks the best-scoring match."""
    if expr.startswith('usda:'):
        return expr[5:] if expr[5:] in foods else None
    if expr.startswith('cnf:') or expr.startswith('fdc:'):
        return expr if expr in foods else None
    must = [w.lower() for w in expr.split() if not w.startswith('!')]
    mustnot = [w[1:].lower() for w in expr.split() if w.startswith('!')]
    best = None
    for ndb, rec in foods.items():
        low = rec['description'].lower()
        if all(re.search(r'\b' + re.escape(w), low) for w in must) and not any(re.search(r'\b' + re.escape(w), low) for w in mustnot):
            sc = variant_score(rec) - (0 if rec['kind'] == 'ingredient' else 40) - (15 if rec['source'] == 'usda-foundation' else 0)
            if best is None or sc > best[0]: best = (sc, ndb)
    return best[1] if best else None

curated, unresolved = [], []
ov_path = os.path.join(HERE, 'overlay', 'curated.csv')
if os.path.exists(ov_path):
    with open(ov_path, encoding='utf-8', newline='') as f:
        for row in csv.DictReader(l for l in f if not l.startswith('#')):
            ndb = find_food(row['usda'].strip())
            if not ndb:
                unresolved.append(row['name']); continue
            curated.append((row, ndb))

def build_ingredient(name, default_ndb, variant_ndbs, row=None):
    d = foods[default_ndb]
    aliases = [a.strip() for a in (row['aliases'].split('|') if row and row.get('aliases') else []) if a.strip()]
    rec = OrderedDict(id=re.sub(r'[^a-z0-9]+', '-', norm(name)).strip('-'), name=name, aliases=aliases, curated=bool(row),
                      aisle=(row.get('aisle') or d['aisle']) if row else d['aisle'], group=d['group'],
                      default_food=d['id'], default_description=d['description'])
    if d.get('description_fr'): rec['name_fr_source'] = d['description_fr']
    rec['per_100g'] = d['per_100g']
    if d.get('density_g_per_ml'): rec['density_g_per_ml'] = d['density_g_per_ml']; rec['density_basis'] = d['density_basis']
    if d.get('unit_weights_g'): rec['unit_weights_g'] = d['unit_weights_g']
    rec['allergens'] = d['allergens']; rec['diet'] = d['diet']
    sl = shelf([name] + aliases)
    if sl: rec['shelf_life'] = sl
    seen, vs = set(), []
    for v in sorted(variant_ndbs, key=lambda n: -variant_score(foods[n])):
        if v in seen: continue
        seen.add(v); vs.append(OrderedDict(food=foods[v]['id'], description=foods[v]['description'], state=foods[v]['state']))
    rec['variants'] = vs[:40]
    rec['variant_count'] = len(vs)
    return rec

ingredients, used_names = [], set()
for row, ndb in curated:
    cname = concept_name(foods[ndb]['description'], None)
    fam = concepts.get(cname, []) if len(concepts.get(cname, [])) <= 60 else []
    ingredients.append(build_ingredient(row['name'], ndb, [ndb] + fam, row))
    used_names.add(skey(row['name']))
    for a in (row.get('aliases') or '').split('|'): used_names.add(skey(a))
gp_path = os.path.join(HERE, 'overlay', 'gaps.csv')
if os.path.exists(gp_path):
    with open(gp_path, encoding='utf-8', newline='') as f:
        for row in csv.DictReader(l for l in f if not l.startswith('#')):
            aliases = [a.strip() for a in row['aliases'].split('|') if a.strip()]
            ingredients.append(OrderedDict(id=re.sub(r'[^a-z0-9]+', '-', norm(row['name'])).strip('-'), name=row['name'], aliases=aliases,
                               curated=True, data_gap=True, gap_note=row['note'], aisle=row['aisle'], group='', default_food=None,
                               default_description='', per_100g={}, allergens=[], diet='unknown', variants=[], variant_count=0))
            used_names.add(skey(row['name']))
            for a in aliases: used_names.add(skey(a))
curated_ids = {i['id'] for i in ingredients}
for cname, ndbs in sorted(concepts.items()):
    if skey(cname) in used_names: continue
    default = max(ndbs, key=lambda n: variant_score(foods[n]))
    rec = build_ingredient(cname[0].upper() + cname[1:], default, ndbs)
    if rec['id'] in curated_ids or not rec['id']: continue
    curated_ids.add(rec['id'])
    ingredients.append(rec)

# ---------------------------------------------------------------- write
with open(os.path.join(OUT, 'foods.jsonl'), 'w', encoding='utf-8') as f:
    for rec in foods.values():
        f.write(json.dumps(rec, ensure_ascii=False, separators=(',', ':')) + '\n')
with open(os.path.join(OUT, 'ingredients.json'), 'w', encoding='utf-8') as f:
    json.dump({'schema': 1, 'count': len(ingredients), 'ingredients': ingredients}, f, ensure_ascii=False, indent=1)
cols = ['id', 'name', 'curated', 'aliases', 'aisle', 'group', 'default_food', 'default_description', 'energy_kcal', 'protein_g',
        'fat_g', 'carbs_g', 'fibre_g', 'sugars_g', 'sodium_mg', 'density_g_per_ml', 'unit_weights_g', 'allergens', 'diet',
        'fridge_days', 'pantry_days', 'freezer_days', 'variant_count']
with open(os.path.join(OUT, 'ingredients.csv'), 'w', encoding='utf-8', newline='') as f:
    w = csv.writer(f); w.writerow(cols)
    for i in ingredients:
        sl = i.get('shelf_life') or {}
        fmt = lambda v: '' if not v else '%d-%d' % tuple(v)
        w.writerow([i['id'], i['name'], 'yes' if i['curated'] else '', '|'.join(i['aliases']), i['aisle'], i['group'], i['default_food'],
                    i['default_description']] + [i['per_100g'].get(k, '') for k in ('energy_kcal', 'protein_g', 'fat_g', 'carbs_g', 'fibre_g', 'sugars_g', 'sodium_mg')] +
                   [i.get('density_g_per_ml', ''), '; '.join('%s=%s' % kv for kv in list((i.get('unit_weights_g') or {}).items())[:6]),
                    '|'.join(i['allergens']), i['diet'], fmt(sl.get('fridge_days')), fmt(sl.get('pantry_days')), fmt(sl.get('freezer_days')), i['variant_count']])

kinds = defaultdict(int)
for r in foods.values(): kinds[r['kind']] += 1
ing_foods = [r for r in foods.values() if r['kind'] == 'ingredient']
stats = OrderedDict(
    foods_total=len(foods), foods_from_usda=sum(1 for r in foods.values() if r['source'] == 'usda'), foods_from_usda_survey=sum(1 for r in foods.values() if r['source'] == 'usda-survey'), foods_from_usda_foundation=sum(1 for r in foods.values() if r['source'] == 'usda-foundation'),
    sr28_foods_with_newer_lab_data=sum(1 for r in foods.values() if r.get('newer_lab_data')), foods_from_cnf=sum(1 for r in foods.values() if r['source'] == 'cnf'),
    foods_by_kind=dict(kinds), measures_from_cnf=sum(1 for r in foods.values() for p in r['measures'] if p.get('source') == 'cnf'),
    foods_with_cooking_yield=sum(1 for r in foods.values() if r.get('yields')),
    foods_with_density=sum(1 for r in foods.values() if r.get('density_g_per_ml')),
    foods_with_unit_weights=sum(1 for r in foods.values() if r.get('unit_weights_g')),
    foods_with_french=sum(1 for r in foods.values() if r.get('description_fr')),
    foods_with_energy=sum(1 for r in foods.values() if 'energy_kcal' in r['per_100g']),
    measures_total=sum(len(r['measures']) for r in foods.values()),
    ingredients_total=len(ingredients), ingredients_curated=sum(1 for i in ingredients if i['curated']),
    ingredients_with_density=sum(1 for i in ingredients if i.get('density_g_per_ml')),
    ingredients_with_unit_weights=sum(1 for i in ingredients if i.get('unit_weights_g')),
    ingredients_with_shelf_life=sum(1 for i in ingredients if i.get('shelf_life')),
    ingredients_with_allergens=sum(1 for i in ingredients if i['allergens']),
    ingredients_data_gaps=[i['name'] for i in ingredients if i.get('data_gap')],
    sr28_may_2016_update=upd_stats, sr_legacy_2018=legacy_stats, survey_foods=survey_stats, curated_unresolved=unresolved)
with open(os.path.join(OUT, 'stats.json'), 'w') as f: json.dump(stats, f, indent=1)
print(json.dumps(stats, indent=1))
