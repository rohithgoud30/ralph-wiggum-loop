#!/bin/bash
set -euo pipefail

# Cleanup function
cleanup() {
  echo ""
  echo "🛑 Script interrupted. Cleaning up..."
  exit 1
}

trap cleanup SIGINT SIGTERM

claude --permission-mode acceptEdits "@plans/prd.json @progress.txt \
IMPORTANT: You must work on exactly ONE task per iteration. \
Start your response with 'TASK: [task name]' to declare which single task you will complete. \
If you try to work on multiple tasks, this iteration will be rejected. \

1. Find the highest-priority feature to work on and work only on that feature. \
This should be the one YOU decide has the highest priority - not necessarily the first in the list. \
2. Check that the types check via pnpm typecheck and that the tests pass via pnpm test. \
3. Update the PRD with the work that was done. \
4. Append your progress to the progress.txt file. \
Use this to leave a note for the next person working in the codebase. \
5. Make a git commit of that feature. \
ONLY WORK ON A SINGLE FEATURE. DO NOT attempt multiple tasks. \
If, while implementing the feature, you notice the PRD is complete, output <promise>COMPLETE</promise>. \
"
