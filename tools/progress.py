#!/usr/bin/env python3
"""Counts, per target, how many methods are translated (no longer call
WG_UNTRANSLATED) and how many plain C functions are still listed."""
import glob
import json
import re

TARGETS = [('SMKGL', 'smkgl'), ('SMKControls', 'smkcontrols'), ('WeatherGlobe', 'wg'),
           ('GlobeScreenSaver', 'saver')]

total_left = total_all = 0
for target, name in TARGETS:
    modules = json.load(open('analysis/objc-%s.json' % name))
    methods = sum(len(c[k]) for m in modules for c in m['classes'] + m['categories']
                  for k in ('imethods', 'cmethods'))
    left = 0
    for path in glob.glob('src/%s/*.m' % target):
        text = open(path, errors='replace').read()
        left += len(re.findall(r'^\s*WG_UNTRANSLATED\(\);', text, re.M))
    funcs = 0
    fpath = 'src/%s/%sFunctions.m' % (target, target)
    try:
        funcs = open(fpath).read().count('--- i386 decompilation')
    except FileNotFoundError:
        pass
    print('%-17s %4d/%4d methods translated, %3d C functions to go'
          % (target, methods - left, methods, funcs))
    total_left += left
    total_all += methods
print('%-17s %4d/%4d methods translated (%.1f%%)'
      % ('total', total_all - total_left, total_all, 100.0 * (total_all - total_left) / total_all))
