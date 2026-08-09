#!/usr/bin/env python3
from __future__ import annotations

import json
import pathlib
from contextlib import suppress

ROOT = pathlib.Path(__file__).resolve().parents[3]
IOS = ROOT / 'learning-sprint' / 'shoshi' / 'ios'
WEB = IOS / 'Web'
AUDIT = IOS / 'audit'


def fail(msg: str) -> None:
    raise AssertionError(msg)


def wait_visible(wait, by, value):
    from selenium.webdriver.support import expected_conditions as EC
    return wait.until(EC.visibility_of_element_located((by, value)))


def main() -> int:
    from selenium import webdriver
    from selenium.webdriver.chrome.options import Options
    from selenium.webdriver.common.by import By
    from selenium.webdriver.support.ui import WebDriverWait

    index = WEB / 'index.html'
    if not index.exists():
        fail('prepare-ios.sh must run before native_ui_audit.py')

    AUDIT.mkdir(parents=True, exist_ok=True)
    driver = None
    try:
        opts = Options()
        opts.add_argument('--headless=new')
        opts.add_argument('--no-sandbox')
        opts.add_argument('--disable-dev-shm-usage')
        opts.add_argument('--allow-file-access-from-files')
        opts.add_argument('--window-size=390,844')
        opts.set_capability('goog:loggingPrefs', {'browser': 'ALL'})
        driver = webdriver.Chrome(options=opts)
        driver.execute_cdp_cmd('Page.addScriptToEvaluateOnNewDocument', {'source': """
          window.__nativeMessages=[];
          window.webkit={messageHandlers:{
            storeKit:{postMessage:(payload)=>window.__nativeMessages.push({name:'storeKit',payload})},
            openExternal:{postMessage:(payload)=>window.__nativeMessages.push({name:'openExternal',payload})}
          }};
        """})
        wait = WebDriverWait(driver, 20)
        driver.get(index.resolve().as_uri())

        wait.until(lambda d: len(d.find_elements(By.CSS_SELECTOR, '.subject-card')) == 11)
        if driver.execute_script('return location.protocol') != 'file:':
            fail('native browser: expected file:// bundle load')
        if len(driver.find_elements(By.CSS_SELECTOR, '#bottomNav button')) != 4:
            fail('native browser: bottom nav != 4')
        if driver.execute_script('return document.documentElement.scrollWidth > window.innerWidth + 1'):
            fail('native browser: horizontal overflow')

        # No hardcoded price: before StoreKit returns a product, purchase is disabled.
        driver.find_element(By.CSS_SELECTOR, '.subject-card').click()
        paywall = wait_visible(wait, By.CSS_SELECTOR, '.native-paywall-backdrop')
        if paywall.get_attribute('hidden'):
            fail('native browser: premium subject did not open paywall')
        buy = driver.find_element(By.CSS_SELECTOR, '[data-native-purchase]')
        if buy.is_enabled():
            fail('native browser: purchase enabled before StoreKit displayPrice')
        driver.save_screenshot(str(AUDIT / 'paywall-unavailable-mobile.png'))

        # Runtime localized price enables the purchase UI; no fixed product price is used here.
        driver.execute_script("window.__nativeStoreKitUpdate({native:true,premium:false,displayPrice:'TEST_PRICE',status:'known'});")
        wait.until(lambda d: d.find_element(By.CSS_SELECTOR, '[data-native-purchase]').is_enabled())
        if 'TEST_PRICE' not in driver.find_element(By.CSS_SELECTOR, '[data-native-price]').text:
            fail('native browser: runtime StoreKit price not rendered')
        driver.save_screenshot(str(AUDIT / 'paywall-price-mobile.png'))
        driver.find_element(By.CSS_SELECTOR, '.native-paywall-close').click()
        wait.until(lambda d: d.find_element(By.CSS_SELECTOR, '.native-paywall-backdrop').get_attribute('hidden') is not None)

        # One daily sprint is available before premium. Complete it to consume trial.
        driver.find_element(By.ID, 'startDaily').click()
        wait_visible(wait, By.ID, 'questionText')
        for i in range(8):
            buttons = driver.find_elements(By.CSS_SELECTOR, '.answer-choice')
            if len(buttons) != 5:
                fail(f'native browser: answer choice count at {i+1} != 5')
            buttons[0].click()
            wait_visible(wait, By.ID, 'feedbackCard')
            driver.find_element(By.ID, 'nextQuestion').click()
            if i < 7:
                wait.until(lambda d: 'hidden' in d.find_element(By.ID, 'feedbackCard').get_attribute('class'))
        wait_visible(wait, By.ID, 'resultView')
        wait.until(lambda d: d.execute_script("return localStorage.getItem('shoshi-native-trial-completed-v1')") == '1')
        driver.save_screenshot(str(AUDIT / 'trial-result-mobile.png'))

        driver.find_element(By.ID, 'backHome').click()
        wait_visible(wait, By.ID, 'homeView')
        driver.find_element(By.ID, 'startDaily').click()
        paywall = wait_visible(wait, By.CSS_SELECTOR, '.native-paywall-backdrop')
        if paywall.get_attribute('hidden'):
            fail('native browser: daily sprint not locked after free trial completion')

        # Restore sends the native bridge action.
        driver.find_element(By.CSS_SELECTOR, '[data-native-restore]').click()
        wait.until(lambda d: d.execute_script("return window.__nativeMessages.some(x=>x.name==='storeKit'&&x.payload.action==='restore')"))

        # Premium entitlement immediately unlocks subject exercise.
        driver.execute_script("window.__nativeStoreKitUpdate({native:true,premium:true,displayPrice:'TEST_PRICE',status:'known'});")
        wait.until(lambda d: d.find_element(By.CSS_SELECTOR, '.native-paywall-backdrop').get_attribute('hidden') is not None)
        driver.find_element(By.CSS_SELECTOR, '.subject-card').click()
        wait_visible(wait, By.ID, 'quizView')
        if 'hidden' not in driver.find_element(By.ID, 'bottomNav').get_attribute('class'):
            fail('native browser: bottom nav visible during premium quiz')

        severe = [x for x in driver.get_log('browser') if x.get('level') == 'SEVERE']
        app_errors = [x for x in severe if 'favicon' not in x.get('message', '').lower()]
        if app_errors:
            fail('native browser console errors: ' + '; '.join(x.get('message','') for x in app_errors[:3]))

        report = {
            'status': 'PASS',
            'bundle_protocol': 'file:',
            'viewport': '390x844',
            'subject_cards': 11,
            'nav_tabs': 4,
            'price_before_storekit': 'disabled',
            'runtime_price_rendered': True,
            'free_trial_questions': 8,
            'trial_lock_after_completion': True,
            'restore_bridge': True,
            'premium_unlock': True,
            'application_console_errors': len(app_errors),
        }
        (IOS / 'native-ui-audit-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return 0
    finally:
        if driver:
            with suppress(Exception):
                driver.quit()


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception as exc:
        report = {'status': 'FAIL', 'error': str(exc)}
        (IOS / 'native-ui-audit-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
        print(json.dumps(report, ensure_ascii=False, indent=2))
        raise
