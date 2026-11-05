#!/usr/bin/env python3
"""Renders SVG files to PNG. Usage: render.py <scale> <svg> [<svg> ...]"""
import sys
from pathlib import Path

from playwright.sync_api import sync_playwright

scale = float(sys.argv[1])
with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page(viewport={"width": 1920, "height": 1080}, device_scale_factor=scale)
    for arg in sys.argv[2:]:
        svg = Path(arg).resolve()
        page.goto(svg.as_uri())
        out = svg.with_suffix(".png")
        page.screenshot(path=str(out))
        print(out)
    browser.close()
