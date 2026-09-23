import asyncio, json, sys
from html import escape as html_escape
from pathlib import Path
from playwright.async_api import async_playwright
S = Path(sys.argv[1]); src = S / sys.argv[2]; out = S / sys.argv[3]
xml = src.read_text(encoding="utf-8")
cfg = json.dumps({"xml": xml, "toolbar": "", "lightbox": False, "nav": False, "border": 20})
html = f'''<html><head><meta charset="utf-8"></head><body style="margin:0;background:#fff">
<div class="mxgraph" style="background:#fff" data-mxgraph="{html_escape(cfg, quote=True)}"></div>
<script src="https://viewer.diagrams.net/js/viewer-static.min.js"></script></body></html>'''
(S / "render.html").write_text(html, encoding="utf-8")
async def m():
    async with async_playwright() as p:
        b = await p.chromium.launch(channel="chrome")
        pg = await (await b.new_context(viewport={"width": 1300, "height": 1200}, device_scale_factor=3)).new_page()
        await pg.goto((S / "render.html").as_uri()); await pg.wait_for_timeout(5000)
        el = await pg.query_selector("div.mxgraph svg")
        if not el: print("렌더 실패"); return
        bb = await el.bounding_box(); print("크기", round(bb["width"]), "x", round(bb["height"]))
        await el.screenshot(path=str(out), omit_background=False)
        await b.close()
asyncio.run(m())
