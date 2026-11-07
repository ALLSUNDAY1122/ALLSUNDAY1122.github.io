-- D2-004 live RLS correction.
-- The storage INSERT/UPDATE policies invoke is_trusted_upload_path as the
-- authenticated role. The helper is a pure immutable predicate, so grant only
-- EXECUTE on this one function while keeping the private schema otherwise closed.
grant execute on function scanlab_private.is_trusted_upload_path(text) to authenticated;
