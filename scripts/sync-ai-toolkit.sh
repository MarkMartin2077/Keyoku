#!/bin/bash
#
# sync-ai-toolkit.sh
# Updates every vendored agent skill to its latest upstream version, re-applies
# local fixups, and lists any skill that .claude/docs/AI-TOOLKIT.md does not cover yet.
#
# Usage:  ./scripts/sync-ai-toolkit.sh            # update + check
#         ./scripts/sync-ai-toolkit.sh --check    # only check the doc

set -e
cd "$(dirname "$0")/.."

if [ "$1" != "--check" ]; then
    echo "Updating project skills from skills-lock.json..."
    npx -y skills@latest update -p -y

    # Paul Hudson's repos ship a nested plugin copy of each skill; Claude Code
    # would list every skill twice, so drop the nested copy.
    for s in swiftui-pro swift-testing-pro swift-concurrency-pro swiftdata-pro; do
        rm -rf ".claude/skills/$s/skills" ".claude/skills/$s/.claude-plugin"
    done
fi

echo "Checking .claude/docs/AI-TOOLKIT.md covers every installed skill..."
missing=0
for dir in .claude/skills/*/; do
    name=$(basename "$dir")
    if ! grep -q "\`/$name\`\|\`$name\`" .claude/docs/AI-TOOLKIT.md; then
        echo "  ⚠️  $name is installed but not documented"
        missing=1
    fi
done
for file in .claude/agents/*.md; do
    name=$(basename "$file" .md)
    if ! grep -q "\`$name\`" .claude/docs/AI-TOOLKIT.md; then
        echo "  ⚠️  agent $name is not documented"
        missing=1
    fi
done

# Project playbooks quote pstack's own step text; a pstack update can break them.
CHECKER="$(ls -d "$HOME"/.claude/plugins/cache/*/pstack/*/skills/poteto-mode/scripts/check-playbooks.mjs 2>/dev/null | sort -V | tail -1)"
if [ -d .agents/playbooks ]; then
    if [ -n "$CHECKER" ] && command -v node >/dev/null 2>&1; then
        echo "Checking .agents/playbooks against the installed pstack..."
        node "$CHECKER" . || missing=1
    else
        echo "  (skipping playbook check: pstack plugin or node not installed)"
    fi
fi

if [ $missing -eq 0 ]; then
    echo "✅ AI-TOOLKIT.md is up to date."
else
    echo "Add the skills above to .claude/docs/AI-TOOLKIT.md (or ask Claude: \"update the AI toolkit doc\")."
    exit 1
fi
