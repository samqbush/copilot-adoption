#!/bin/bash

# Replace these variables with your actual values
USER="samqbush"
PROJECT_ID="PVT_kwHOBG8ZT84AyULV"

# Get the project details using GraphQL
project_query() {
  gh api graphql --paginate -f query='
  query($projectId: ID!) {
    node(id: $projectId) {
      ... on ProjectV2 {
        title
        items(first: 100) {
          nodes {
            content {
              ... on Issue {
                title
                number
                body
                createdAt
                updatedAt
                url
              }
              ... on DraftIssue {
                title
                body
                createdAt
                updatedAt
              }
            }
          }
        }
      }
    }
  }' -f projectId=$PROJECT_ID
}

# Fetch the project data
project_data=$(project_query)

# Extract the issues and draft issues
issues=$(echo $project_data | jq -r '.data.node.items.nodes | map(select(.content != null))')

# Output the collected issues to a JSON file
echo $issues | jq '.' > project_issues.json

echo "Exported issues to project_issues.json"