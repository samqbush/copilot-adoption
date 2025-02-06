#!/bin/bash

# This script automates the creation and management of GitHub Enterprise teams and their mapping to Identity Provider (IDP) groups.
# 
# Prerequisites:
# - Authenticate with the GitHub CLI using "gh auth login" with a token that has appropriate access. The user must be an enterprise owner.
# - Ensure the GitHub CLI (gh) and jq are installed on your system.
#
# Variables:
# - EMU_SLUG: The slug of the GitHub Enterprise Managed User (EMU) instance.
# - TEAM_NAME: The name of the team to be created or checked.
# - TEAM_DESCRIPTION: A description for the team.
# - IDP_GROUP_NAME: The name of the IDP group to be mapped to the team.
#
# Steps:
# 1. Check if the team already exists in the specified EMU.
# 2. If the team does not exist, create it with the specified name and description.
# 3. Retrieve the team's ID and name to verify its creation.
# 4. Get the ID of the specified IDP group.
# 5. Validate that both the team ID and IDP group ID were successfully retrieved.
# 6. Update the team with the IDP group mapping using the retrieved IDs.
#
# Usage:
# - Customize the variables (EMU_SLUG, TEAM_NAME, TEAM_DESCRIPTION, IDP_GROUP_NAME) as needed.
# - Run the script in a shell environment.

# Variables for testing
EMU_SLUG=octodemo-copilot-standalone
TEAM_NAME=samq-test
TEAM_DESCRIPTION="SamQ Api test"
IDP_GROUP_NAME="SE Field Administrators"

# Check if the team already exists
TEAM_EXISTS=$(gh api enterprises/$EMU_SLUG/teams | jq -r --arg TEAM_NAME "$TEAM_NAME" '.[] | select(.name == $TEAM_NAME) | .name')

if [ -z "$TEAM_EXISTS" ]; then
    # Create the team in the specified emu
    gh api enterprises/$EMU_SLUG/teams -X POST -f name="$TEAM_NAME" -f description="$TEAM_DESCRIPTION"
    echo "Team '$TEAM_NAME' created."
else
    echo "Team '$TEAM_NAME' already exists."
fi

# Verify the team creation and get id
TEAM_INFO=$(gh api enterprises/$EMU_SLUG/teams | jq -r --arg TEAM_NAME "$TEAM_NAME" '.[] | select(.name == $TEAM_NAME) | {id, name}')
TEAM_ID=$(echo $TEAM_INFO | jq -r '.id')
TEAM_NAME=$(echo $TEAM_INFO | jq -r '.name')
echo "Team ID: $TEAM_ID"
echo "Team Name: $TEAM_NAME"

# Get the ID for the IDP group
IDP_ID=$(gh api scim/v2/enterprises/$EMU_SLUG/Groups | jq -r --arg IDP_GROUP_NAME "$IDP_GROUP_NAME" '.Resources[] | select(.displayName==$IDP_GROUP_NAME) | .id')
echo "External ID: $IDP_ID"

# Validate variables
if [ -z "$TEAM_ID" ] || [ -z "$IDP_ID" ]; then
    echo "Error: Could not find team ID or external ID"
    exit 1
fi

# Update team with group mapping
gh api enterprises/$EMU_SLUG/teams/$TEAM_NAME -X PATCH -f group_id="$IDP_ID"