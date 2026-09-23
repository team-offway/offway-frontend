"""README 의 기술 스택 · 아키텍처 이미지를 다시 뽑는다.

HTML 을 고친 뒤 이 폴더에서:  python3 render.py
(playwright 와 Chrome 이 필요하다 — pip install playwright)
두 배 해상도로 찍어 ../tech-stack.png · ../architecture.png 를 덮어쓴다.
"""
import asyncio
from pathlib import Path
from playwright.async_api import async_playwright

HERE = Path(__file__).parent
JOBS = [("tech-stack.html", 1440, "../tech-stack.png"),
        ("architecture.html", 1360, "../architecture.png")]


async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(channel="chrome")
        for src, width, out in JOBS:
            page = await (await browser.new_context(
                viewport={"width": width, "height": 1000}, device_scale_factor=2)).new_page()
            await page.goto((HERE / src).resolve().as_uri())
            await page.wait_for_timeout(2500)  # 웹폰트(Pretendard) 로딩
            await (await page.query_selector("#shot")).screenshot(path=str(HERE / out))
            print("생성:", out)
        await browser.close()

asyncio.run(main())
