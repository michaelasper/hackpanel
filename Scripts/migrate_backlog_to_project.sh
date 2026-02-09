#!/usr/bin/env bash
set -euo pipefail

OWNER="michaelasper"
REPO="hackpanel"
PROJECT_ID="PVT_kwHOAV741s4BOr8E"  # user project: hackpanel
REPO_ID="R_kgDORLmzMA"

# Fields
STATUS_FIELD_ID="PVTSSF_lAHOAV741s4BOr8Ezg9UI5k"
PRIORITY_FIELD_ID="PVTSSF_lAHOAV741s4BOr8Ezg9UI9o"
SIZE_FIELD_ID="PVTSSF_lAHOAV741s4BOr8Ezg9UI9s"

# Options
STATUS_BACKLOG="f75ad846"

PRIO_P0="79628723"
PRIO_P1="0a877460"
PRIO_P2="da944a9c"

SIZE_S="f784b110"
SIZE_M="7515a9f1"

create_issue() {
  local title="$1"
  local body="$2"
  gh api graphql \
    -f query='mutation($repoId:ID!,$title:String!,$body:String!){createIssue(input:{repositoryId:$repoId,title:$title,body:$body}){issue{id number url}}}' \
    -f repoId="$REPO_ID" -f title="$title" -f body="$body" \
    --jq '.data.createIssue.issue'
}

add_to_project() {
  local content_id="$1"
  gh api graphql \
    -f query='mutation($projectId:ID!,$contentId:ID!){addProjectV2ItemById(input:{projectId:$projectId,contentId:$contentId}){item{id}}}' \
    -f projectId="$PROJECT_ID" -f contentId="$content_id" \
    --jq '.data.addProjectV2ItemById.item.id'
}

set_single_select() {
  local item_id="$1"
  local field_id="$2"
  local option_id="$3"
  gh api graphql \
    -f query='mutation($projectId:ID!,$itemId:ID!,$fieldId:ID!,$optionId:String!){updateProjectV2ItemFieldValue(input:{projectId:$projectId,itemId:$itemId,fieldId:$fieldId,value:{singleSelectOptionId:$optionId}}){projectV2Item{id}}}' \
    -f projectId="$PROJECT_ID" -f itemId="$item_id" -f fieldId="$field_id" -f optionId="$option_id" \
    --silent
}

# Minimal mapping from BACKLOG.md sections → project fields.
# Everything starts in Status=Backlog.
# Priority: Next=P1, Soon=P2, Later=P2 (adjust manually after import).
# Size default: M.

import_item() {
  local section="$1" # Next|Soon|Later
  local title="$2"

  local prio="$PRIO_P2"
  case "$section" in
    Next) prio="$PRIO_P1";;
    Soon) prio="$PRIO_P2";;
    Later) prio="$PRIO_P2";;
  esac

  local body
  body=$(cat <<EOF
Imported from BACKLOG.md (${section}).

## Acceptance criteria
- [ ] 

## Notes
- 
EOF
)

  echo "Creating issue: [$section] $title" >&2
  local issue_json
  issue_json=$(create_issue "$title" "$body")
  local issue_id
  issue_id=$(jq -r '.id' <<<"$issue_json")
  local issue_url
  issue_url=$(jq -r '.url' <<<"$issue_json")

  local item_id
  item_id=$(add_to_project "$issue_id")
  set_single_select "$item_id" "$STATUS_FIELD_ID" "$STATUS_BACKLOG"
  set_single_select "$item_id" "$PRIORITY_FIELD_ID" "$prio"
  set_single_select "$item_id" "$SIZE_FIELD_ID" "$SIZE_M"

  echo "$issue_url" >&2
}

# Parse BACKLOG.md: grab bullet lines under Next/Soon/Later.
next_items=$(awk '/^## Next/{flag=1;next}/^## Soon/{flag=0} flag && /^- /{sub(/^- /,""); print}' BACKLOG.md)
soon_items=$(awk '/^## Soon/{flag=1;next}/^## Later/{flag=0} flag && /^- /{sub(/^- /,""); print}' BACKLOG.md)
later_items=$(awk '/^## Later/{flag=1;next}/^## Done/{flag=0} flag && /^- /{sub(/^- /,""); print}' BACKLOG.md)

IFS=$'\n'
for t in $next_items; do [ -n "$t" ] && import_item Next "$t"; done
for t in $soon_items; do [ -n "$t" ] && import_item Soon "$t"; done
for t in $later_items; do [ -n "$t" ] && import_item Later "$t"; done
unset IFS

echo "Done. Review the Project board and de-dupe/adjust priorities." >&2
