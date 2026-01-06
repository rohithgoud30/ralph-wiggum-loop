#!/bin/bash
set -euo pipefail

# ============================================
# Ralph - Claude Automation Script
# ============================================
# This script automates feature development using Claude CLI.
# 
# Prerequisites:
#   1. Create plans/plan.md with your project requirements
#   2. Run this script - it will generate prd.json first
#   3. Then iterate through features automatically
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLANS_DIR="$SCRIPT_DIR/.."
PROJECT_ROOT="$PLANS_DIR/.."
PLAN_FILE="$PLANS_DIR/plan.md"
PRD_FILE="$PLANS_DIR/prd.json"
PROGRESS_FILE="$PROJECT_ROOT/progress.txt"
RALPH_DIR="$PROJECT_ROOT/.ralph"
LOGS_DIR="$RALPH_DIR/logs"

# Stop conditions
MAX_REPEATED_FAILURES=3
LAST_FAILURE_HASH=""
FAILURE_COUNT=0

# Cleanup function
cleanup() {
  echo ""
  echo "🛑 Script interrupted. Cleaning up..."
  exit 1
}

trap cleanup SIGINT SIGTERM

# Create directories
mkdir -p "$LOGS_DIR"

# Check for iterations argument
if [ -z "${1:-}" ]; then
  echo "Usage: $0 <iterations>"
  echo ""
  echo "Before running, create plans/plan.md with your project requirements."
  echo "See plans/example-prd.json for the PRD format reference."
  exit 1
fi

# Check if plan.md exists
if [ ! -f "$PLAN_FILE" ]; then
  echo "❌ Error: plans/plan.md not found!"
  echo ""
  echo "Please create plans/plan.md with your project requirements first."
  exit 1
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Progress Log" > "$PROGRESS_FILE"
  echo "Created: $(date)" >> "$PROGRESS_FILE"
  echo "" >> "$PROGRESS_FILE"
fi

# Generate or update prd.json from plan.md
echo "📋 Generating prd.json from plan.md..."
echo "--------------------------------"

claude -p "Read the @plans/plan.md file and generate a prd.json file in the plans directory. \
Use @plans/example-prd.json as a reference for the JSON structure. \
The prd.json should include: \
- Project name and description \
- List of features with id, name, description, priority (high/medium/low), status (pending), and tasks \
- Tech stack information \
- Any constraints mentioned \
Parse the plan.md content and organize it into this structured format. \
Output only the JSON file, no explanations."

if [ ! -f "$PRD_FILE" ]; then
  echo "❌ Error: Failed to generate prd.json"
  exit 1
fi

echo ""
echo "✅ prd.json generated successfully!"
echo "--------------------------------"
echo ""

# Start feature iterations
echo "🚀 Starting feature iterations..."
echo ""

for ((i=1; i<=$1; i++)); do
  ITER_LOG="$LOGS_DIR/iter-$(printf '%02d' $i).txt"
  
  echo "Iteration $i of $1"
  echo "--------------------------------"
  echo "📝 Logging to: $ITER_LOG"
  
  # Capture git state before iteration
  GIT_HASH_BEFORE=$(git rev-parse HEAD 2>/dev/null || echo "no-git")
  
  # Log iteration start
  {
    echo "=== Iteration $i ==="
    echo "Started: $(date)"
    echo ""
  } > "$ITER_LOG"
  
  result=$(claude --permission-mode acceptEdits -p "@plans/prd.json @progress.txt \
IMPORTANT: You must work on exactly ONE task per iteration. \
Start your response with 'TASK: [task name]' to declare which single task you will complete. \
If you try to work on multiple tasks, this iteration will be rejected. \

1. Find the highest-priority feature to work on and work only on that feature. \
This should be the one YOU decide has the highest priority - not necessarily the first in the list. \
2. Check that the types check via pnpm typecheck and that the tests pass via pnpm test. \
3. Update the PRD with the work that was done (change status to 'completed'). \
4. Append your progress to the progress.txt file. \
Use this to leave a note for the next person working in the codebase. \
5. Make a git commit of that feature. \
ONLY WORK ON A SINGLE FEATURE. DO NOT attempt multiple tasks. \
If PRD is complete, output <promise>COMPLETE</promise>. \
If you encounter a fatal error you cannot recover from, output <promise>FATAL</promise>. \
" 2>&1 | tee -a "$ITER_LOG")

  # Log iteration end
  {
    echo ""
    echo "Ended: $(date)"
    echo "=== End Iteration $i ==="
  } >> "$ITER_LOG"

  # Check for COMPLETE signal
  if [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
    echo ""
    echo "🎉 PRD complete, exiting."
    exit 0
  fi
  
  # Check for FATAL signal
  if [[ "$result" == *"<promise>FATAL</promise>"* ]]; then
    echo ""
    echo "💀 Fatal error detected, exiting."
    exit 1
  fi
  
  # Check if no files changed (agent stuck)
  GIT_HASH_AFTER=$(git rev-parse HEAD 2>/dev/null || echo "no-git")
  if [ "$GIT_HASH_BEFORE" = "$GIT_HASH_AFTER" ]; then
    if git diff --quiet 2>/dev/null; then
      echo ""
      echo "⚠️  No changes detected in iteration $i. Agent may be stuck."
      # Continue but warn - could add counter here to exit after N stuck iterations
    fi
  fi
  
  # Check for repeated failures (hash test output)
  if [[ "$result" == *"FAIL"* ]] || [[ "$result" == *"error"* ]]; then
    CURRENT_FAILURE_HASH=$(echo "$result" | grep -i -E "(FAIL|error)" | head -5 | md5sum | cut -d' ' -f1)
    if [ "$CURRENT_FAILURE_HASH" = "$LAST_FAILURE_HASH" ]; then
      FAILURE_COUNT=$((FAILURE_COUNT + 1))
      echo "⚠️  Same failure repeated ($FAILURE_COUNT/$MAX_REPEATED_FAILURES)"
      if [ "$FAILURE_COUNT" -ge "$MAX_REPEATED_FAILURES" ]; then
        echo ""
        echo "💀 Same failure repeated $MAX_REPEATED_FAILURES times. Exiting."
        exit 1
      fi
    else
      LAST_FAILURE_HASH="$CURRENT_FAILURE_HASH"
      FAILURE_COUNT=1
    fi
  else
    # Reset failure tracking on success
    LAST_FAILURE_HASH=""
    FAILURE_COUNT=0
  fi
  
  echo ""
done

echo "✅ Completed $1 iterations."
