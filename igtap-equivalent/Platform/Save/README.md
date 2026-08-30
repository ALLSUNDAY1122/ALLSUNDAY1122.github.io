# Save ownership

Session C owns local save schema, migration, corruption fallback, best-times/settings metadata and lifecycle-triggered flushes. Implementation is scheduled for C Next 2. Session B only serializes/deserializes its progression state through the interface contract.
