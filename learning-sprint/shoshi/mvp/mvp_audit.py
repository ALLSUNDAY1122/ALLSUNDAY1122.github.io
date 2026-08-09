#!/usr/bin/env python3
from __future__ import annotations

import json
import pathlib
import subprocess
import sys
import time
from contextlib import suppress

ROOT = pathlib.Path(__file__).resolve().parents[3]
MVP = ROOT / 'learning-sprint' / 'shoshi' / 'mvp'
DATA = ROOT / 'learning-sprint' / 'shoshi' / 'content-loop' / 'questions.generated.json'


def fail(msg: str) -> None:
    raise AssertionError(msg)


def static_audit() -> dict:
    html = (MVP / 'index.html').read_text(encoding='utf-8')
    css = (MVP / 'styles.css').read_text(encoding='utf-8')
    js = (MVP / 'app.js').read_text(encoding='utf-8')
    manifest = json.loads((MVP / 'manifest.webmanifest').read_text(encoding='utf-8'))
    sw = (MVP / 'sw.js').read_text(encoding='utf-8')
    questions = json.loads(DATA.read_text(encoding='utf-8'))

    if len(questions) != 210:
        fail(f'questions={len(questions)}/210')
    if len({q['id'] for q in questions}) != 210:
        fail('duplicate question ids')
    r7pm33 = next(q for q in questions if q['id'] == 'SHOSHI-R7-PM-33')
    if r7pm33.get('scoring_status') != 'all_correct' or r7pm33.get('official_answer_no') is not None:
        fail('R7 PM33 all_correct contract broken')
    if 'user-scalable=no' in html:
        fail('zoom must not be disabled')
    if html.count('data-nav=') != 4:
        fail('bottom navigation must have exactly four tabs')
    if manifest.get('orientation') != 'portrait' or manifest.get('display') != 'standalone':
        fail('PWA portrait/standalone contract missing')
    if '../content-loop/questions.generated.json' not in sw:
        fail('service worker does not cache question dataset')
    if 'max-width:520px' not in css.replace(' ', ''):
        fail('520px Golden Master width missing')
    if 'state.dailyGoal = Number' not in js or 'consecutiveCorrect >= 3' not in js:
        fail('daily goal or weak-release logic missing')
    if 'official_answer_no' not in js or "scoring_status === 'all_correct'" not in js:
        fail('official answer/all-correct handling missing')
    if 'exportData' not in js or 'importData' not in js:
        fail('JSON import/export implementation missing')

    return {
        'questions': 210,
        'unique_ids': 210,
        'r7pm33': 'all_correct',
        'nav_tabs': 4,
        'pwa': True,
        'json_import_export': True,
    }


def wait_sw_ready(driver, timeout=15) -> bool:
    driver.set_script_timeout(timeout)
    return bool(driver.execute_async_script("""
        const done = arguments[arguments.length - 1];
        if (!('serviceWorker' in navigator)) { done(false); return; }
        navigator.serviceWorker.ready.then(async () => {
          const keys = await caches.keys();
          const hits = [];
          for (const key of keys) {
            const cache = await caches.open(key);
            const requests = await cache.keys();
            hits.push(...requests.map(r => r.url));
          }
          done(hits.some(u => u.endsWith('/questions.generated.json')) && hits.some(u => u.includes('/shoshi/mvp/')));
        }).catch(() => done(false));
    """))


def browser_audit() -> dict:
    from selenium import webdriver
    from selenium.webdriver.chrome.options import Options
    from selenium.webdriver.common.by import By
    from selenium.webdriver.support.ui import WebDriverWait
    from selenium.webdriver.support import expected_conditions as EC

    server = subprocess.Popen(
        [sys.executable, '-m', 'http.server', '8765', '--bind', '127.0.0.1'],
        cwd=ROOT,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    driver = None
    network_offline = False
    try:
        time.sleep(1)
        opts = Options()
        opts.add_argument('--headless=new')
        opts.add_argument('--no-sandbox')
        opts.add_argument('--disable-dev-shm-usage')
        opts.add_argument('--window-size=390,844')
        opts.set_capability('goog:loggingPrefs', {'browser': 'ALL'})
        driver = webdriver.Chrome(options=opts)
        wait = WebDriverWait(driver, 15)
        url = 'http://127.0.0.1:8765/learning-sprint/shoshi/mvp/'
        driver.get(url)

        wait.until(lambda d: len(d.find_elements(By.CSS_SELECTOR, '.subject-card')) == 11)
        if len(driver.find_elements(By.CSS_SELECTOR, '#bottomNav button')) != 4:
            fail('browser: bottom nav != 4')
        if driver.execute_script('return document.documentElement.scrollWidth > window.innerWidth + 1'):
            fail('browser: horizontal overflow on 390px viewport')
        shell_width = driver.execute_script("return document.querySelector('.app-shell').getBoundingClientRect().width")
        if shell_width > 520.5:
            fail(f'browser: shell width {shell_width} > 520')

        audit_dir = MVP / 'audit'
        audit_dir.mkdir(exist_ok=True)
        driver.save_screenshot(str(audit_dir / 'home-mobile.png'))

        driver.find_element(By.ID, 'startDaily').click()
        wait.until(EC.visibility_of_element_located((By.ID, 'questionText')))
        if 'hidden' not in driver.find_element(By.ID, 'bottomNav').get_attribute('class'):
            fail('browser: bottom nav visible during quiz')
        if len(driver.find_elements(By.CSS_SELECTOR, '.answer-choice')) != 5:
            fail('browser: answer buttons != 5')
        qtext = driver.find_element(By.ID, 'questionText').text
        if len(qtext) < 40:
            fail('browser: question text too short')
        driver.find_elements(By.CSS_SELECTOR, '.answer-choice')[0].click()
        wait.until(EC.visibility_of_element_located((By.ID, 'feedbackCard')))
        if driver.find_element(By.ID, 'gradingMark').text not in ('○', '×'):
            fail('browser: grading mark missing')
        driver.save_screenshot(str(audit_dir / 'quiz-feedback-mobile.png'))
        driver.find_element(By.ID, 'headerHome').click()
        wait.until(EC.visibility_of_element_located((By.ID, 'homeView')))

        driver.find_element(By.CSS_SELECTOR, '[data-nav="mock"]').click()
        wait.until(lambda d: len(d.find_elements(By.CSS_SELECTOR, '.mock-card')) == 6)
        driver.find_element(By.CSS_SELECTOR, '[data-nav="record"]').click()
        wait.until(lambda d: len(d.find_elements(By.CSS_SELECTOR, '.heat-cell')) == 35)
        driver.save_screenshot(str(audit_dir / 'record-mobile.png'))
        driver.find_element(By.CSS_SELECTOR, '[data-nav="settings"]').click()
        wait.until(EC.visibility_of_element_located((By.ID, 'settingsView')))
        if len(driver.find_elements(By.CSS_SELECTOR, '[data-font]')) != 3:
            fail('browser: font controls != 3')
        if len(driver.find_elements(By.CSS_SELECTOR, '[data-goal]')) != 3:
            fail('browser: goal controls != 3')
        driver.save_screenshot(str(audit_dir / 'settings-mobile.png'))

        min_bottom_h = min(driver.execute_script('return arguments[0].getBoundingClientRect().height', b) for b in driver.find_elements(By.CSS_SELECTOR, '#bottomNav button'))
        if min_bottom_h < 44:
            fail(f'browser: bottom nav touch target {min_bottom_h}px < 44px')

        import_file = pathlib.Path('/tmp/shoshi-import-audit.json')
        import_file.write_text(json.dumps({'state': {
            'version': 1, 'attempts': {}, 'studyDays': {}, 'dailyGoal': 4,
            'fontSize': 'large', 'examDate': '', 'activeYear': 2025
        }}, ensure_ascii=False), encoding='utf-8')
        driver.find_element(By.ID, 'importData').send_keys(str(import_file))
        wait.until(lambda d: 'active' in d.find_element(By.CSS_SELECTOR, '[data-goal="4"]').get_attribute('class'))
        if driver.execute_script("return getComputedStyle(document.documentElement).getPropertyValue('--font-scale').trim()") != '1.12':
            fail('browser: imported fontSize was not applied')

        driver.execute_script("localStorage.clear()")
        driver.get(url)
        wait.until(lambda d: len(d.find_elements(By.CSS_SELECTOR, '.subject-card')) == 11)

        sw_cached = wait_sw_ready(driver)
        if not sw_cached:
            fail('browser: service worker cache not ready')

        driver.execute_cdp_cmd('Network.enable', {})
        driver.execute_cdp_cmd('Network.emulateNetworkConditions', {
            'offline': True, 'latency': 0, 'downloadThroughput': 0, 'uploadThroughput': 0,
            'connectionType': 'none'
        })
        network_offline = True
        driver.refresh()
        wait.until(lambda d: len(d.find_elements(By.CSS_SELECTOR, '.subject-card')) == 11)
        offline_load = True

        driver.execute_cdp_cmd('Network.emulateNetworkConditions', {
            'offline': False, 'latency': 0, 'downloadThroughput': -1, 'uploadThroughput': -1,
            'connectionType': 'wifi'
        })
        network_offline = False

        severe = [x for x in driver.get_log('browser') if x.get('level') == 'SEVERE']
        app_errors = [x for x in severe if 'ERR_INTERNET_DISCONNECTED' not in x.get('message','')]
        if app_errors:
            fail('browser application console errors: ' + '; '.join(x.get('message','') for x in app_errors[:3]))

        return {
            'viewport': '390x844',
            'subject_cards': 11,
            'mock_cards': 6,
            'heatmap_cells': 35,
            'application_console_errors': len(app_errors),
            'horizontal_overflow': False,
            'min_bottom_touch_target': min_bottom_h,
            'json_import': True,
            'service_worker_cache_ready': sw_cached,
            'offline_reload': offline_load,
        }
    finally:
        if driver:
            if network_offline:
                with suppress(Exception):
                    driver.execute_cdp_cmd('Network.emulateNetworkConditions', {
                        'offline': False, 'latency': 0, 'downloadThroughput': -1, 'uploadThroughput': -1,
                        'connectionType': 'wifi'
                    })
            with suppress(Exception):
                driver.quit()
        server.terminate()
        with suppress(Exception):
            server.wait(timeout=5)


def main() -> int:
    report = {'static': static_audit(), 'browser': browser_audit(), 'status': 'PASS'}
    out = MVP / 'mvp-audit-report.json'
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as exc:
        report = {'status': 'FAIL', 'error': str(exc)}
        (MVP / 'mvp-audit-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
        print(json.dumps(report, ensure_ascii=False, indent=2))
        raise
