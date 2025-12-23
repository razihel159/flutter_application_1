assets/README.md

This folder contains GeoJSON assets used by the app (e.g., `philippines.json`).

License status
- As of this commit, the assets in this folder do NOT contain an embedded `license` or `source` field.
- The origin and license of `assets/philippines.json` are UNKNOWN. Do NOT redistribute these files until you verify the license.

How to verify
1. Check repo history (git) for the commit that added the asset and its commit message.
2. Look for adjacent documentation or a `LICENSE` / `ASSET_LICENSES.md` file in the repo.
3. Inspect the GeoJSON for a `properties.source`, `copyright`, or `license` field.
4. If still unknown, search the web for distinctive property keys (e.g., `ADM1_PCODE`, `ADM1_EN`) or content to find the original dataset (common sources: GADM, Natural Earth, OpenStreetMap extracts, PhilGIS).

Common sources & licensing notes (examples)
- Natural Earth: public domain (no attribution required but recommended).
- OpenStreetMap: ODbL – requires attribution and share-alike when redistributing derived datasets.
- GADM: has license terms that may restrict commercial use; verify at https://gadm.org.

Recommended actions
- If you confirm a source and a permissive license: add a file `ASSET_LICENSES.md` (or add to this README) stating the source, version, license, and required attribution text.
- If the license is restrictive or unknown: do not publish the asset, and consider replacing it with a known-permission dataset (e.g., Natural Earth or an OSM-extract with explicit ODbL attribution).

Attribution example (for OSM/ODbL data)
"Contains data from OpenStreetMap contributors, licensed under ODbL (https://www.openstreetmap.org/copyright)."

If you want, I can:
- Search the repo for the commit that added these files and attempt to find a source link.
- Add an `ASSET_LICENSES.md` entry and/or add an in-app data source/attribution UI.
