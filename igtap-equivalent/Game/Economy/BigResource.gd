class_name BigResource
extends RefCounted

const BASE := 1000.0
const PRECISION_GROUPS := 8
const ZERO_EPSILON := 1.0e-12

var mantissa: float = 0.0
var exponent: int = 0

func _init(value: float = 0.0, group_exponent: int = 0) -> void:
    mantissa = value
    exponent = maxi(group_exponent, 0)
    _normalize()

static func from_number(value: float):
    if not is_finite(value):
        return null
    return BigResource.new(value, 0)

static func from_snapshot(snapshot: Dictionary):
    var value := float(snapshot.get("mantissa", 0.0))
    var group_exponent := int(snapshot.get("exponent", 0))
    if not is_finite(value) or group_exponent < 0:
        return null
    return BigResource.new(value, group_exponent)

func copy():
    return BigResource.new(mantissa, exponent)

func is_zero() -> bool:
    return absf(mantissa) <= ZERO_EPSILON

func is_negative() -> bool:
    return mantissa < -ZERO_EPSILON

func snapshot() -> Dictionary:
    return {"mantissa": mantissa, "exponent": exponent}

func signed_snapshot(sign_value: float) -> Dictionary:
    var sign_multiplier := -1.0 if sign_value < 0.0 else 1.0
    return {"mantissa": absf(mantissa) * sign_multiplier, "exponent": exponent}

func compare(other) -> int:
    if is_zero() and other.is_zero():
        return 0
    if is_negative() != other.is_negative():
        return -1 if is_negative() else 1
    var sign_multiplier := -1 if is_negative() else 1
    if exponent != other.exponent:
        return sign_multiplier if exponent > other.exponent else -sign_multiplier
    if is_equal_approx(mantissa, other.mantissa):
        return 0
    return 1 if mantissa > other.mantissa else -1

func add_assign(other) -> void:
    if other == null or other.is_zero():
        return
    if is_zero():
        mantissa = other.mantissa
        exponent = other.exponent
        _normalize()
        return
    var difference := exponent - other.exponent
    if difference > PRECISION_GROUPS:
        return
    if difference < -PRECISION_GROUPS:
        mantissa = other.mantissa
        exponent = other.exponent
        _normalize()
        return
    if difference >= 0:
        mantissa += other.mantissa / pow(BASE, difference)
    else:
        mantissa = mantissa / pow(BASE, -difference) + other.mantissa
        exponent = other.exponent
    _normalize()

func subtract_assign(other) -> bool:
    if other == null or other.is_negative():
        return false
    if compare(other) < 0:
        return false
    var negative := other.copy()
    negative.mantissa *= -1.0
    add_assign(negative)
    if mantissa < 0.0 and absf(mantissa) <= ZERO_EPSILON:
        mantissa = 0.0
        exponent = 0
    return not is_negative()

func multiply_assign(factor: float) -> bool:
    if not is_finite(factor) or factor < 0.0:
        return false
    mantissa *= factor
    _normalize()
    return true

func divide_assign(divisor: float) -> bool:
    if not is_finite(divisor) or divisor <= 0.0:
        return false
    mantissa /= divisor
    _normalize()
    return true

func to_float_clamped(max_value: float = 1.0e300) -> float:
    if is_zero():
        return 0.0
    var decimal_exponent := exponent * 3
    if decimal_exponent >= 300:
        return -max_value if is_negative() else max_value
    var value := mantissa * pow(BASE, exponent)
    if not is_finite(value) or absf(value) > max_value:
        return -max_value if is_negative() else max_value
    return value

func _normalize() -> void:
    if not is_finite(mantissa):
        mantissa = 0.0
        exponent = 0
        return
    if absf(mantissa) <= ZERO_EPSILON:
        mantissa = 0.0
        exponent = 0
        return
    while absf(mantissa) >= BASE:
        mantissa /= BASE
        exponent += 1
    while exponent > 0 and absf(mantissa) < 1.0:
        mantissa *= BASE
        exponent -= 1
