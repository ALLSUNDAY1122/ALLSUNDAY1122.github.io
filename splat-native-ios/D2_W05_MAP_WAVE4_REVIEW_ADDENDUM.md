# D2 W05 Wave 4 harsh-review addendum

Date: 2026-08-17 JST

This addendum narrows and corrects the Wave 4 evidence after live deployment review.

## Migration-history correction

Supabase recorded the production migration as:

`20260816160353 scanlab_d2_optional_public_geotag_v12`

The repository migration filename is therefore aligned to the same version:

`supabase/migrations/20260816160353_scanlab_d2_optional_public_geotag_v12.sql`

This avoids leaving a differently-versioned SQL migration in source control that a later migration runner could treat as unapplied.

## Exact scope of the optional-geotag fix

Wave 4 closes the active W05 initial trusted-publish path:

- public without location -> Discover/public URL, no Map pin;
- public with explicit location -> Map + Discover;
- privacy and rights confirmations remain mandatory for public;
- public-place confirmation is mandatory only when a geotag is attached.

Production `scanlab-publish` v4 and the database v12 constraint/trigger use this contract.

## Cross-worker dependency found after deployment

The concurrently developed W03-owned production `scanlab-visibility` v2 still requires latitude/longitude when an already-published scan is transitioned to `public`.

W05 does not overwrite `scanlab-visibility` or the W03 branch. Therefore Wave 4 must not be interpreted as proving that every future visibility-transition path already supports location-free public state. That remaining inconsistency belongs to W03/integration reconciliation.

This does not invalidate the W05 initial-publish fix, because the W05 trusted publish path uses `scanlab-publish`, not `scanlab-visibility`.

## Remaining physical proof

Production still has no real scan rows. Final parity evidence remains:

1. real trusted 3D -> public without geotag -> Discover yes / Map no;
2. real trusted 3D -> public with explicit geotag -> Map yes;
3. open the real Map item from another environment;
4. after W03 integration, confirm a visibility transition to public can also remain location-free when the owner does not opt into Map.

No fake/demo row is acceptable for these proofs.
