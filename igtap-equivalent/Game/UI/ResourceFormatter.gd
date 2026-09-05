class_name ResourceFormatter
extends RefCounted

const BigResourceType = preload("res://Game/Economy/BigResource.gd")
const EconomyCatalogType = preload("res://Game/Economy/EconomyCatalog.gd")

var _catalog := EconomyCatalogType.new()
var _loaded := false

func load_catalog() -> Error:
    var error := _catalog.load_from_paths()
    _loaded = error == OK
    return error

func format_resource(snapshot: Dictionary, decimals: int = 2) -> String:
    if not _loaded:
        var error := load_catalog()
        if error != OK:
            return "0 Flux"
    var value = BigResourceType.from_snapshot(snapshot)
    if value == null or value.is_zero():
        return "0 " + _catalog.resource_name()
    var suffixes := _catalog.display_suffixes()
    var digits := clampi(decimals, 0, 4)
    var number_text := String.num(value.mantissa, digits)
    if value.exponent >= 0 and value.exponent < suffixes.size():
        return number_text + " " + str(suffixes[value.exponent])
    return number_text + " e" + str(value.exponent * 3) + " " + _catalog.resource_name()

func format_rate(snapshot: Dictionary, decimals: int = 2) -> String:
    return format_resource(snapshot, decimals) + "/s"
