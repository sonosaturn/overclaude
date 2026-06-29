# shellcheck shell=sh
# merge_settings EXISTING TEMPLATE -> merged JSON on stdout.
# Recursive object merge; template wins on scalar conflicts; existing-only keys kept.
# ponytail: arrays are replaced by template's version (not concatenated). If a user
# hand-adds custom hooks/permissions arrays under a managed key, re-running overwrites
# that array. Upgrade path: switch to a keyed deep-merge if that ever bites.
merge_settings() {
  existing="$1"; template="$2"
  if [ -f "$existing" ] && [ -s "$existing" ]; then
    jq -s '.[0] * .[1]' "$existing" "$template"
  else
    jq '.' "$template"
  fi
}
