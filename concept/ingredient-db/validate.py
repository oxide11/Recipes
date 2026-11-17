#!/usr/bin/env python3
"""Checks on the built database. Run after build.py: python3 -I validate.py"""
import json, os, re, sys, unicodedata
HERE = os.path.dirname(os.path.abspath(__file__))
ings = json.load(open(os.path.join(HERE, 'out', 'ingredients.json'), encoding='utf-8'))['ingredients']
foods = [json.loads(l) for l in open(os.path.join(HERE, 'out', 'foods.jsonl'), encoding='utf-8')]

def norm(s):
    s = unicodedata.normalize('NFKD', s).encode('ascii', 'ignore').decode().lower()
    return ' '.join(re.sub(r'[^a-z0-9% ]+', ' ', s).split())
def singular(w):
    if w.endswith('ies') and len(w) > 4: return w[:-3] + 'y'
    if w.endswith('oes') and len(w) > 4: return w[:-2]
    if w.endswith('ses') or w.endswith('ss') or w.endswith('us'): return w
    return w[:-1] if w.endswith('s') and len(w) > 3 else w
def key(s): return ' '.join(singular(w) for w in norm(s).split())

index = {}
for i in ings:                      # curated first, so they win
    if i['curated']:
        for n in [i['name']] + i['aliases']: index.setdefault(key(n), i)
for i in ings:
    if not i['curated']: index.setdefault(key(i['name']), i)

fails = 0
print('== 1. Every ingredient in the prototype recipes resolves ==')
proto = json.load(open(os.path.join(HERE, 'tests', 'prototype_ingredients.json'), encoding='utf-8'))
miss, auto, checked, off = [], [], 0, []
for p in proto:
    i = index.get(key(p['name']))
    if not i: miss.append(p['name']); continue
    if not i['curated']: auto.append(p['name'])
    kc = i['per_100g'].get('energy_kcal')
    if kc is not None and p['grams'] >= 20 and p['kcal']:
        checked += 1
        mine = p['kcal'] / p['grams'] * 100
        if abs(mine - kc) > max(40, 0.35 * kc): off.append((p['recipe'], p['name'], round(mine), kc, i['default_description']))
print('  %d ingredient lines, %d distinct names' % (len(proto), len({key(p['name']) for p in proto})))
print('  not found: %s' % (sorted(set(miss)) or 'none'))
print('  found only in the automatic list (not curated): %s' % (sorted(set(auto)) or 'none'))
fails += len(set(miss))
print('== 2. Prototype calories against the database (lines of 20 g or more) ==')
print('  %d compared, %d differ by more than 35%%' % (checked, len(off)))
for o in off: print('   %-9s %-22s prototype %4d kcal/100g, database %4d  (%s)' % o)

print('== 3. Internal consistency of the nutrition data ==')
bad = []
for f in foods:
    n = f['per_100g']
    if all(k in n for k in ('energy_kcal', 'protein_g', 'fat_g', 'carbs_g')):
        est = 4 * n['protein_g'] + 9 * n['fat_g'] + 4 * n['carbs_g'] + 7 * n.get('alcohol_g', 0)
        if abs(est - n['energy_kcal']) > max(45, 0.25 * n['energy_kcal']): bad.append((f['id'], f['description'][:60], n['energy_kcal'], round(est)))
print('  energy vs 4-9-4 estimate: %d of %d foods differ by more than 25%% (fibre and sugar alcohols explain most)' % (len(bad), len(foods)))
macro = [f['id'] for f in foods if sum(f['per_100g'].get(k, 0) for k in ('protein_g', 'fat_g', 'carbs_g', 'water_g', 'alcohol_g')) > 104]
print('  protein + fat + carbs + water over 104 g per 100 g: %d' % len(macro))
dens = [(f['id'], f['description'][:50], f['density_g_per_ml']) for f in foods if f.get('density_g_per_ml') and not 0.05 <= f['density_g_per_ml'] <= 1.6]
print('  density outside 0.05 to 1.6 g/ml: %d %s' % (len(dens), dens[:4]))
ids = [i['id'] for i in ings]
dup = len(ids) - len(set(ids))
print('  duplicate ingredient ids: %d' % dup); fails += dup
gaps = [i['name'] for i in ings if i.get('data_gap')]
noen = [i['name'] for i in ings if 'energy_kcal' not in i['per_100g'] and not i.get('data_gap')]
print('  ingredients without energy: %d' % len(noen)); fails += len(noen)
print('  known gaps (listed, no nutrition yet): %s' % (gaps or 'none'))

print('== 4. Spot values: the Standard Reference figure, before any newer lab value replaced it (reference in brackets) ==')
spot = [('Butter', 'energy_kcal', 717), ('Egg', 'protein_g', 12.56), ('Flour', 'carbs_g', 76.31), ('Olive oil', 'fat_g', 100), ('Sugar', 'energy_kcal', 387)]
for name, k, ref in spot:
    it = index[key(name)]; v = (it.get('latest_lab') or {}).get('superseded', {}).get(k, it['per_100g'].get(k)); ok = v is not None and abs(v - ref) <= 0.02 * ref + 0.01
    print('  %-10s %-12s %s [%s] %s' % (name, k, v, ref, 'ok' if ok else 'MISMATCH')); fails += 0 if ok else 1
cups = [('Flour', 125), ('Sugar', 200), ('Butter', 227), ('Honey', 339), ('Milk', 244)]
for name, g in cups:
    d = index[key(name)].get('density_g_per_ml'); got = round(d * 236.588) if d else None
    ok = got is not None and abs(got - g) <= 0.06 * g
    print('  %-10s 1 cup = %s g [about %d] %s' % (name, got, g, 'ok' if ok else 'CHECK')); fails += 0 if ok else 1
print('RESULT: %s' % ('all checks passed' if not fails else '%d failures' % fails))
sys.exit(1 if fails else 0)
