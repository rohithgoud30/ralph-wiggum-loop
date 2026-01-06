#!/bin/bash
set -e

# ============================================
# Ralph - Claude Automation Script
# ============================================
# This script automates feature development using Claude CLI.
# 
# Prerequisites:
#   1. Create plans/plan.md with your project requirements
#   2. Run this script - it will generate prd.json first
#   3. Then iterate through features automatically
#
# Example plan.md content:
#   # Project: My API
#   ## Features
#   - User authentication with JWT
#   - Dashboard REST endpoints
#   - Email notifications
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLANS_DIR="$SCRIPT_DIR/.."
PLAN_FILE="$PLANS_DIR/plan.md"
PRD_FILE="$PLANS_DIR/prd.json"
PROGRESS_FILE="$PLANS_DIR/../progress.txt"

# Check for iterations argument
if [ -z "$1" ]; then
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
  echo "Example content:"
  echo "  # Project: My API"
  echo "  ## Features"
  echo "  - Feature 1 description"
  echo "  - Feature 2 description"
  echo ""
  echo "See plans/example-prd.json for the expected PRD format."
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
  echo "Iteration $i of $1"
  echo "--------------------------------"
  
  result=$(claude --permission-mode acceptEdits -p "@plans/prd.json @progress.txt \
1. Find the highest-priority feature to work on and work only on that feature. \
This should be the one YOU decide has the highest priority - not necessarily the first in the list. \
2. Check that the types check via pnpm typecheck and that the tests pass via pnpm test. \
3. Update the PRD with the work that was done (change status to 'completed'). \
4. Append your progress to the progress.txt file. \
Use this to leave a note for the next person working in the codebase. \
5. Make a git commit of that feature. \
ONLY WORK ON A SINGLE FEATURE. \
If, while implementing the feature, you notice the PRD is complete, output <promise>COMPLETE</promise>. \
")

  echo "$result"

  if [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
    echo ""
    echo "🎉 PRD complete, exiting."
    tt notify "CVM PRD complete after $i iterations"
    exit 0
  fi
  
  echo ""
done

echo "✅ Completed $1 iterations."
