class_name StageSelectModel
extends RefCounted

var _stage_source: Node

func bind(stage_source: Node) -> void:
    _stage_source = stage_source

func entries() -> Array[Dictionary]:
    if _stage_source == null or not _stage_source.has_method("stage_select_entries"):
        return []
    return _stage_source.call("stage_select_entries")

func select(stage_id: StringName) -> bool:
    if _stage_source == null or not _stage_source.has_method("select_stage"):
        return false
    if _stage_source.has_method("is_stage_available") and not bool(_stage_source.call("is_stage_available", stage_id)):
        return false
    return bool(_stage_source.call("select_stage", stage_id))
