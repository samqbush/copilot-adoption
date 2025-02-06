#!/bin/bash

# [Setup IDP integration](https://docs.github.com/en/enterprise-cloud@latest/admin/managing-iam/provisioning-user-accounts-with-scim/configuring-scim-provisioning-for-users#about-provisioning-for-enterprise-managed-users)
# [Create Enterprise Teams via API](https://docs.github.com/en/enterprise-cloud@latest/early-access/admin/articles/rest-api-endpoints-for-enterprise-teams)
# [Assign licenses to Users via Teams](https://docs.github.com/en/enterprise-cloud@latest/admin/copilot-business-only/setting-up-a-dedicated-enterprise-for-copilot-business-managed-users#assigning-licenses-to-users)
#   - [Using the User Interface](https://docs.github.com/en/enterprise-cloud@latest/admin/copilot-business-only/setting-up-a-dedicated-enterprise-for-copilot-business-managed-users#assigning-licenses-to-a-team)
#   - Using the API
#       - Find external/IDP ids using [API](https://docs.github.com/en/enterprise-cloud@latest/rest/enterprise-admin/scim?apiVersion=2022-11-28#list-provisioned-scim-groups-for-an-enterprise)
#       - Update GitHub Enterprise team with group id using [API](https://docs.github.com/en/enterprise-cloud@latest/early-access/admin/articles/rest-api-endpoints-for-enterprise-teams#update-an-enterprise-team)
# This script uses the GH CLI to 

# Make sure to authenticate with the GH CLI using "gh auth login" and a token with appropriate access - User must be an enterprise owner
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
#gh api scim/v2/enterprises/$EMU_SLUG/Groups | jq '.Resources[] | {displayName, externalId, id}'
IDP_ID=$(gh api scim/v2/enterprises/$EMU_SLUG/Groups | jq -r --arg IDP_GROUP_NAME "$IDP_GROUP_NAME" '.Resources[] | select(.displayName==$IDP_GROUP_NAME) | .id')
echo "External ID: $IDP_ID"

# Validate variables
if [ -z "$TEAM_ID" ] || [ -z "$IDP_ID" ]; then
    echo "Error: Could not find team ID or external ID"
    exit 1
fi

# Update team with group mapping
gh api enterprises/$EMU_SLUG/teams/$TEAM_NAME -X PATCH -f group_id="$IDP_ID"


