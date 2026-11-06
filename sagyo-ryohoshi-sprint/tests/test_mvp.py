#!/usr/bin/env python3
import http.server
import json
import socket
import socketserver
import threading
import unittest
from collections import Counter
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
QUESTIONS = ROOT / "sagyo-ryohoshi-sprint" / "mvp" / "questions.json"
PREVIEW = ROOT / "previews" / "sagyo-ryohoshi-sprint" / "index.html"
EXPECTED_SUBJECTS = {
    "解剖学", "生理学", "運動学", "病理学概論", "臨床心理学",
    "リハビリテーション医学", "臨床医学大要", "作業療法",
}


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        pass


def free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


class MvpContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.questions = json.loads(QUESTIONS.read_text(encoding="utf-8"))

    def test_question_bank_has_16_real_questions(self):
        self.assertEqual(len(self.questions), 16)
        self.assertEqual(set(q["subject"] for q in self.questions), EXPECTED_SUBJECTS)
        self.assertEqual(Counter(q["subject"] for q in self.questions), Counter({s: 2 for s in EXPECTED_SUBJECTS}))

    def test_question_contract(self):
        required = {
            "id", "round", "exam_reference", "session", "slot", "question_type",
            "subject", "topic", "question", "choices", "correct_indices", "explanation",
            "memory_point", "source_url", "answer_source_url", "source_checked_at",
            "origin_type", "rights_basis",
        }
        ids = set()
        texts = set()
        for q in self.questions:
            self.assertTrue(required.issubset(q), q.get("id"))
            self.assertNotIn(q["id"], ids)
            ids.add(q["id"])
            normalized = "".join(q["question"].split())
            self.assertNotIn(normalized, texts)
            texts.add(normalized)
            self.assertEqual(q["round"], "R1")
            self.assertEqual(q["session"], "AM")
            self.assertEqual(q["question_type"], "general")
            self.assertIn(q["subject"], EXPECTED_SUBJECTS)
            self.assertEqual(len(q["choices"]), 5)
            self.assertEqual(len(q["correct_indices"]), 1)
            self.assertIn(q["correct_indices"][0], range(5))
            self.assertTrue(q["source_url"].startswith("https://www.mhlw.go.jp/"))
            self.assertTrue(q["answer_source_url"].startswith("https://www.mhlw.go.jp/"))
            self.assertIn("PDL1.0", q["rights_basis"])
            self.assertGreaterEqual(len(q["explanation"]), 20)
            self.assertGreaterEqual(len(q["memory_point"]), 8)

    def test_preview_embeds_required_ui_contract(self):
        html = PREVIEW.read_text(encoding="utf-8")
        for token in [
            "学びスプリント", "作業療法士国家試験", "今日も1問、力に変える。",
            "今日のスプリント", "分野から解く", "ここだけ覚える",
            "ホーム", "模試", "記録", "設定", "--paper:#f7f3ea", "max-width:520px",
        ]:
            self.assertIn(token, html)
        self.assertIn("sagyo-ryohoshi-sprint/mvp/questions.json", html)
        self.assertIn("data-testid=\"feedback\"", html)


class BrowserSmokeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.port = free_port()
        handler = lambda *args, **kwargs: QuietHandler(*args, directory=str(ROOT), **kwargs)
        cls.httpd = socketserver.TCPServer(("127.0.0.1", cls.port), handler)
        cls.thread = threading.Thread(target=cls.httpd.serve_forever, daemon=True)
        cls.thread.start()
        cls.playwright = sync_playwright().start()
        cls.browser = cls.playwright.chromium.launch(
            executable_path="/usr/bin/chromium",
            headless=True,
            args=["--no-sandbox", "--disable-dev-shm-usage"],
        )

    @classmethod
    def tearDownClass(cls):
        cls.browser.close()
        cls.playwright.stop()
        cls.httpd.shutdown()
        cls.httpd.server_close()

    def test_home_subject_quiz_feedback_result_history_flow(self):
        page = self.browser.new_page(viewport={"width": 390, "height": 844})
        html = PREVIEW.read_text(encoding="utf-8")
        payload = QUESTIONS.read_text(encoding="utf-8")
        html = html.replace("<head>", f"<head><script>window.__MVP_QUESTIONS__={payload};</script>", 1)
        page.set_content(html, wait_until="load")

        self.assertTrue(page.get_by_test_id("screen-home").is_visible())
        page.locator('[data-subject="解剖学"]').click()
        self.assertTrue(page.get_by_test_id("screen-quiz").is_visible())
        self.assertIn("運動神経線維のみ", page.get_by_test_id("question-text").inner_text())

        page.locator('[data-choice="4"]').click()
        self.assertTrue(page.get_by_test_id("feedback").is_visible())
        self.assertIn("正解", page.get_by_test_id("feedback").inner_text())
        self.assertIn("ここだけ覚える", page.get_by_test_id("feedback").inner_text())
        page.get_by_test_id("next-question").click()

        self.assertIn("尺骨神経", page.get_by_test_id("question-text").inner_text())
        page.locator('[data-choice="1"]').click()
        self.assertTrue(page.get_by_test_id("feedback").is_visible())
        page.get_by_test_id("next-question").click()

        self.assertTrue(page.get_by_test_id("screen-result").is_visible())
        self.assertIn("2 / 2", page.get_by_test_id("screen-result").inner_text())
        page.get_by_test_id("result-history").click()
        self.assertTrue(page.get_by_test_id("screen-history").is_visible())
        self.assertIn("2", page.locator("#hCount").inner_text())
        self.assertGreaterEqual(page.locator(".history-item").count(), 2)
        page.close()

    def test_today_sprint_has_eight_subjects(self):
        page = self.browser.new_page(viewport={"width": 390, "height": 844})
        html = PREVIEW.read_text(encoding="utf-8")
        payload = QUESTIONS.read_text(encoding="utf-8")
        html = html.replace("<head>", f"<head><script>window.__MVP_QUESTIONS__={payload};</script>", 1)
        page.set_content(html, wait_until="load")
        page.get_by_test_id("start-sprint").click()
        self.assertTrue(page.get_by_test_id("screen-quiz").is_visible())
        self.assertIn("1 / 8", page.locator("#position").inner_text())
        page.close()


if __name__ == "__main__":
    unittest.main(verbosity=2)
