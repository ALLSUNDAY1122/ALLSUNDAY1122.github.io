-- D2-004 server-side draft creation support.
-- Edge Functions use service_role to create the owner-bound draft row. The
-- trusted asset trigger calls a helper in scanlab_private, so grant only the
-- minimum schema/function privileges required for that trusted server path.
grant usage on schema scanlab_private to service_role;
grant execute on function scanlab_private.is_trusted_upload_path(text) to service_role;
