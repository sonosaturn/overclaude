# shellcheck shell=sh
# run_component TYPE NAME ARG. With DRY_RUN=1, echo the command instead of running it.
_rc_exec() { if [ "${DRY_RUN:-0}" = "1" ]; then echo "$*"; else eval "$*"; fi; }
run_component() {
  type="$1"; name="$2"; arg="$3"
  case "$type" in
    plugin)     _rc_exec "claude plugin marketplace add $arg && claude plugin install ${name}@${name}" ;;
    mcp)        _rc_exec "claude mcp add $name -- $arg" ;;
    cmd)        _rc_exec "$arg" ;;
    npm-global) _rc_exec "npm install -g $arg" ;;
    uv-tool)    _rc_exec "uv tool install $arg" ;;
    skills-cli) _rc_exec "npx skills@latest add $arg --skill $name --agent claude --global --yes" ;;
    *) echo "unknown component type: $type" >&2; return 1 ;;
  esac
}
