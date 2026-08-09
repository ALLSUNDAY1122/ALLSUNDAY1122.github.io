#!/usr/bin/env python3
from __future__ import annotations
import json,pathlib
from contextlib import suppress
ROOT=pathlib.Path(__file__).resolve().parents[3]
IOS=ROOT/'learning-sprint'/'shoshi'/'ios'; WEB=IOS/'Web'; AUDIT=IOS/'audit'
def fail(msg): raise AssertionError(msg)
def main():
    from selenium import webdriver
    from selenium.webdriver.chrome.options import Options
    from selenium.webdriver.common.by import By
    from selenium.webdriver.support.ui import WebDriverWait
    from selenium.webdriver.support import expected_conditions as EC
    index=WEB/'index.html'
    if not index.exists(): fail('prepare-ios.sh must run before native_ui_audit.py')
    AUDIT.mkdir(parents=True,exist_ok=True); driver=None
    try:
        opts=Options()
        for arg in ['--headless=new','--no-sandbox','--disable-dev-shm-usage','--allow-file-access-from-files','--window-size=390,844']: opts.add_argument(arg)
        opts.set_capability('goog:loggingPrefs',{'browser':'ALL'})
        driver=webdriver.Chrome(options=opts)
        driver.execute_cdp_cmd('Page.addScriptToEvaluateOnNewDocument',{'source':"""window.__nativeMessages=[];window.webkit={messageHandlers:{storeKit:{postMessage:p=>window.__nativeMessages.push({name:'storeKit',payload:p})},openExternal:{postMessage:p=>window.__nativeMessages.push({name:'openExternal',payload:p})}}};"""})
        wait=WebDriverWait(driver,20); driver.get(index.resolve().as_uri())
        wait.until(lambda d:len(d.find_elements(By.CSS_SELECTOR,'.subject-card'))==11)
        if driver.execute_script('return location.protocol')!='file:': fail('expected file:// bundle load')
        if len(driver.find_elements(By.CSS_SELECTOR,'#bottomNav button'))!=4: fail('bottom nav != 4')
        if driver.execute_script('return document.documentElement.scrollWidth > window.innerWidth + 1'): fail('horizontal overflow')

        # Premium-only subject must open a modal, without exposing a false/fixed price.
        subject=driver.find_element(By.CSS_SELECTOR,'.subject-card'); subject.click()
        wait.until(EC.visibility_of_element_located((By.CSS_SELECTOR,'.native-paywall-backdrop')))
        if not driver.execute_script("return document.querySelector('#appShell').inert === true"): fail('background is not inert while paywall is open')
        if driver.execute_script("return document.activeElement?.classList.contains('native-paywall-close')") is not True: fail('close button did not receive focus')
        buy=driver.find_element(By.CSS_SELECTOR,'[data-native-purchase]')
        if buy.is_enabled(): fail('purchase enabled before StoreKit displayPrice')
        driver.save_screenshot(str(AUDIT/'paywall-unavailable-mobile.png'))

        driver.execute_script("window.__nativeStoreKitUpdate({native:true,premium:false,displayPrice:'TEST_PRICE',status:'known'});")
        wait.until(lambda d:d.find_element(By.CSS_SELECTOR,'[data-native-purchase]').is_enabled())
        if 'TEST_PRICE' not in driver.find_element(By.CSS_SELECTOR,'[data-native-price]').text: fail('runtime StoreKit price not rendered')
        driver.save_screenshot(str(AUDIT/'paywall-price-mobile.png'))

        # Small-height iPhone-class viewport: dialog itself must stay inside the viewport and scroll internally.
        driver.set_window_size(390,667)
        rect=driver.execute_script("const r=document.querySelector('.native-paywall').getBoundingClientRect();return {top:r.top,bottom:r.bottom,height:r.height,innerHeight:innerHeight,scrollHeight:document.querySelector('.native-paywall').scrollHeight};")
        if rect['top'] < -1 or rect['bottom'] > rect['innerHeight']+1: fail(f"paywall outside small viewport: {rect}")
        driver.save_screenshot(str(AUDIT/'paywall-small-mobile.png'))
        driver.set_window_size(390,844)

        driver.find_element(By.CSS_SELECTOR,'.native-paywall-close').click()
        wait.until(lambda d:d.find_element(By.CSS_SELECTOR,'.native-paywall-backdrop').get_attribute('hidden') is not None)
        if driver.execute_script("return document.querySelector('#appShell').inert === true"): fail('background remained inert after closing paywall')

        # One full daily sprint is the free trial.
        driver.find_element(By.ID,'startDaily').click(); wait.until(EC.visibility_of_element_located((By.ID,'questionText')))
        for i in range(8):
            buttons=driver.find_elements(By.CSS_SELECTOR,'.answer-choice')
            if len(buttons)!=5: fail(f'answer choice count at {i+1} != 5')
            buttons[0].click(); wait.until(EC.visibility_of_element_located((By.ID,'feedbackCard'))); driver.find_element(By.ID,'nextQuestion').click()
            if i<7: wait.until(lambda d:'hidden' in d.find_element(By.ID,'feedbackCard').get_attribute('class'))
        wait.until(EC.visibility_of_element_located((By.ID,'resultView')))
        wait.until(lambda d:d.execute_script("return localStorage.getItem('shoshi-native-trial-completed-v1')")=='1')
        driver.save_screenshot(str(AUDIT/'trial-result-mobile.png'))
        driver.find_element(By.ID,'backHome').click(); wait.until(EC.visibility_of_element_located((By.ID,'homeView')))
        driver.find_element(By.ID,'startDaily').click(); wait.until(EC.visibility_of_element_located((By.CSS_SELECTOR,'.native-paywall-backdrop')))

        driver.find_element(By.CSS_SELECTOR,'[data-native-restore]').click()
        wait.until(lambda d:d.execute_script("return window.__nativeMessages.some(x=>x.name==='storeKit'&&x.payload.action==='restore')"))
        driver.execute_script("window.__nativeStoreKitUpdate({native:true,premium:true,displayPrice:'TEST_PRICE',status:'known'});")
        wait.until(lambda d:d.find_element(By.CSS_SELECTOR,'.native-paywall-backdrop').get_attribute('hidden') is not None)
        driver.find_element(By.CSS_SELECTOR,'.subject-card').click(); wait.until(EC.visibility_of_element_located((By.ID,'quizView')))
        if 'hidden' not in driver.find_element(By.ID,'bottomNav').get_attribute('class'): fail('bottom nav visible during premium quiz')
        severe=[x for x in driver.get_log('browser') if x.get('level')=='SEVERE']; app_errors=[x for x in severe if 'favicon' not in x.get('message','').lower()]
        if app_errors: fail('console errors: '+'; '.join(x.get('message','') for x in app_errors[:3]))
        report={'status':'PASS','bundle_protocol':'file:','viewport':'390x844 + 390x667 paywall','subject_cards':11,'nav_tabs':4,'price_before_storekit':'disabled','runtime_price_rendered':True,'free_trial_questions':8,'trial_lock_after_completion':True,'restore_bridge':True,'premium_unlock':True,'modal_background_inert':True,'small_viewport_contained':True,'application_console_errors':len(app_errors)}
        (IOS/'native-ui-audit-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8'); print(json.dumps(report,ensure_ascii=False,indent=2)); return 0
    finally:
        if driver:
            with suppress(Exception): driver.quit()
if __name__=='__main__':
    try: raise SystemExit(main())
    except Exception as exc:
        report={'status':'FAIL','error':str(exc)};(IOS/'native-ui-audit-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(report,ensure_ascii=False,indent=2));raise
