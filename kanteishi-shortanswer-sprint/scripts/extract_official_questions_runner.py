#!/usr/bin/env python3
"""Compatibility runner for MLIT PDF layout variations."""

import re

import extract_official_questions as extractor

# pdftotext may omit the Japanese corner brackets or insert layout spacing.
# Digits must follow 問題 immediately (apart from whitespace), so this does not
# match prose such as 問題用紙.
extractor.QUESTION_MARKER_RE = re.compile(
    r"(?:〔\s*)?問\s*題\s*([0-9０-９]+)(?:\s*〕)?"
)

# Some administrative-law PDFs contain artificial inter-glyph spaces from the
# embedded Japanese font. Japanese question text does not depend on those spaces,
# so normalize them away before storing canonical text.
_base_compact = extractor.compact


def compact_without_pdf_spacing(text: str) -> str:
    return re.sub(r"\s+", "", _base_compact(text))


extractor.compact = compact_without_pdf_spacing

# Avoid false positives such as 情報の提供 / 財務諸表 / 公表. Only explicit
# source/credit notation is treated as a possible third-party-rights signal.
extractor.THIRD_PARTY_RE = re.compile(
    r"(?:出典\s*[:：]|転載\s*[:：]|©|Copyright|(?:写真|図版|資料)提供\s*[:：])",
    re.IGNORECASE,
)

# Layout-dependent tables/figures need app rendering review, but a table created
# by MLIT is not itself a third-party-rights failure. Keep the two concerns separate.
extractor.VISUAL_RE = re.compile(
    r"(?:下\s*表|次\s*表|下\s*図|次\s*図|表\s*の\s*[ア-ン]|資料\s*[0-9０-９]+|図\s*に\s*示|表\s*に\s*示)"
)

_base_make_item = extractor.make_item

Q39_STEM = """土地Ｂの所有者が、土地Ｂとの併合を目的として隣接する土地Ａを取得する際の限定価格を求めるに当たり、次の表のアからエに当てはまる数値の組合せとして正しいものはどれか。配分率は小数点以下第4位を四捨五入し、金額は千円未満を四捨五入する。

【併合前・併合後の条件】
・土地A（併合される土地）：300㎡、個別的要因格差率105/100、標準価格500,000円/㎡、単価525,000円/㎡、総額157,500,000円
・土地B（併合する土地）：500㎡、個別的要因格差率98/100、標準価格500,000円/㎡、単価490,000円/㎡、総額245,000,000円
・土地C（併合後）：800㎡、個別的要因格差率110/100、標準価格500,000円/㎡、単価550,000円/㎡、総額440,000,000円

【求める値】
ア：単価比による土地Aへの配分率
イ：単価比による増分価値の土地Aへの配分額
ウ：総額比による土地Aへの配分率
エ：総額比による増分価値の土地Aへの配分額"""

Q40_STEM = """対象不動産（低層戸建住宅）について、次の前提条件に基づき、原価法により積算価格を求めた場合の計算結果として正しいものはどれか。前提条件以外の数値の検討は不要とし、各計算過程では千円未満を四捨五入する。

【前提条件】
1. 対象土地の再調達原価：50,000,000円（価格時点現在、減価修正不要）
2. 対象建物の竣工時建設費：本体建設費用（値引き前）20,000,000円。親族施工のため1,000,000円値引きされ、実支払額は19,000,000円
3. 竣工から価格時点まで10年経過し、その間の工事物価上昇率は10％
4. 躯体の物理的耐用年数：65年
5. 価格時点における建物の経済的残存耐用年数：30年
6. 建物の減価額：耐用年数に基づく定額法で把握
7. 経済的残存耐用年数満了時の残価率：0％"""


def make_item_with_separate_layout_review(src, qno, stem, choices, answer):
    item = _base_make_item(src, qno, stem, choices, answer)
    layout_review = bool(item.get("requiresVisualRightsReview"))
    third_party_review = bool(item.get("requiresThirdPartyRightsReview"))
    item["requiresLayoutReview"] = layout_review
    item["requiresVisualRightsReview"] = layout_review
    item["rightsStatus"] = "review_required" if third_party_review else "text_only_pass"
    item["releaseEligible"] = not third_party_review

    if src.edition == 2026 and src.subject == extractor.THEORY and qno == 39:
        item["question"] = Q39_STEM
        item["memoryLine"] = "併合増分37,500,000円を、単価比ではA:0.517、総額比ではA:0.391で配分する。"
        item["shortExplanation"] = "併合による増分価値は37,500,000円。単価比A=525/(525+490)=0.517、総額比A=157.5/(157.5+245)=0.391。"
        item["detailExplanation"] = (
            "正解は(3)です。併合前のA・B合計額は157,500,000円+245,000,000円=402,500,000円、"
            "併合後Cは440,000,000円なので、併合による増分価値は37,500,000円です。"
            "単価比でAへ配分する率は525,000÷(525,000+490,000)=約0.517で、"
            "配分額は37,500,000×0.517=約19,388,000円。"
            "総額比でAへ配分する率は157,500,000÷402,500,000=約0.391で、"
            "配分額は37,500,000×0.391=約14,663,000円となります。"
        )
        item["layoutReviewStatus"] = "pass_text_reconstruction"
        item["editedNotice"] = "国土交通省公表PDFの表を、数値関係を保持した箇条書き形式へ再構成。設問・選択肢・数値の意味は改変しない。"
    elif src.edition == 2026 and src.subject == extractor.THEORY and qno == 40:
        item["question"] = Q40_STEM
        item["memoryLine"] = "親族値引きは正常化して20百万円→物価補正22百万円。経済的総耐用40年で10年分減価し、建物16.5百万円。土地と合計66.5百万円。"
        item["shortExplanation"] = "建物再調達原価22,000,000円、経済的総耐用年数40年、10年経過の定額減価5,500,000円。積算価格は66,500,000円。"
        item["detailExplanation"] = (
            "正解は(4)の66,500,000円です。親族関係による1,000,000円の値引きは市場相場からの乖離なので、"
            "竣工時建設費は値引き前20,000,000円を採用します。これを工事物価10％上昇で価格時点へ補正すると"
            "再調達原価は22,000,000円です。経済的総耐用年数は経過10年+経済的残存30年=40年。"
            "残価率0％の定額法では10年分の減価額は22,000,000×10/40=5,500,000円、"
            "建物価格は16,500,000円。土地50,000,000円を加えて66,500,000円となります。"
        )
        item["layoutReviewStatus"] = "pass_text_reconstruction"
        item["editedNotice"] = "国土交通省公表PDFの前提条件表を、数値関係を保持した箇条書き形式へ再構成。設問・選択肢・数値の意味は改変しない。"

    return item


extractor.make_item = make_item_with_separate_layout_review

if __name__ == "__main__":
    extractor.main()
