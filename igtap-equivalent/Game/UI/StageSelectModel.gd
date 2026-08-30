class_name StageSelectModel
extends RefCounted

var _stage_manager: Node

func bind(stage_manager: Node) -> void:
    _stage_manager = stage_manager

func entries() -> Array[Dictionary]:
    if _stage_manager == null or not _stage_manager.has_method("stage_select_entries"):
        return []
    return _stage_manager.stage_select_entries()

func select(stage_id: StringName) -> bool:
    if _stage_manager == null or not _stage_manager.has_method("select_stage"):
        return false
    return _stage_manager.select_stage(stage_id)
