"""Shared conservative PDF glyph normalizer and suspicious-text checks."""
import re,unicodedata
FONT_GLYPH_MAP={2:"2",4:"1",5:"3",6:"4",7:"5",8:"9",11:"6",12:"7",31:"（"}
SUSPICIOUS=re.compile(r"[\x00-\x1f\x7f\ufffd઄¹¼ïñèêçâ]|[!?]|(?:[A-Za-z]{1,}V[A-Za-z]{1,})")
def clean_font(s):
    text=str(s).translate(str.maketrans(FONT_GLYPH_MAP))
    return re.sub(r"（([^（！!\n]{0,90})!",r"（\1）",text)
def norm(s):
    return re.sub(r"\s+","",unicodedata.normalize("NFKC",clean_font(s))).replace("～","~").replace("〜","~").replace("−","-").replace("‐","-")
def suspicious(s):
    return bool(SUSPICIOUS.search(s) or re.search(r"[\u0080-\u009f\u00a1-\u00ff]",s) or re.search(r"DKIX|[前後]H-\d+|[-−]H[-−]\d+",s))
