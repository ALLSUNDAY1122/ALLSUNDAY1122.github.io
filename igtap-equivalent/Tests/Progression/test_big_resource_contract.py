from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BIG = ROOT / "Game" / "Economy" / "BigResource.gd"
FORMATTER = ROOT / "Game" / "UI" / "ResourceFormatter.gd"


def normalize(mantissa, exponent):
    if abs(mantissa) <= 1.0e-12:
        return 0.0, 0
    while abs(mantissa) >= 1000.0:
        mantissa /= 1000.0
        exponent += 1
    while exponent > 0 and abs(mantissa) < 1.0:
        mantissa *= 1000.0
        exponent -= 1
    return mantissa, exponent


def test_large_number_model_survives_extreme_exponents():
    mantissa, exponent = normalize(9.75e15, 180)
    assert 1.0 <= mantissa < 1000.0
    assert exponent == 185
    assert exponent * 3 == 555


def test_big_resource_exposes_required_arithmetic():
    text = BIG.read_text(encoding="utf-8")
    for token in ["const BASE := 1000.0", "func add_assign", "func subtract_assign", "func multiply_assign", "func divide_assign", "func compare", "func snapshot", "func to_float_clamped"]:
        assert token in text


def test_storage_is_separate_from_display_suffixes():
    big_text = BIG.read_text(encoding="utf-8")
    formatter_text = FORMATTER.read_text(encoding="utf-8")
    assert "kFlux" not in big_text
    assert "display_suffixes" in formatter_text
