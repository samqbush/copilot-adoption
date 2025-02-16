#!/bin/bash

# The following script exports issues from a GitHub project to a CSV file for import into JIRA.
# This script can be used to export the GitHub Copilot Adoption Blueprint project.
# Map the title to summary and map the body to description.

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

# Extract title and body, and convert to CSV format
csv_data=$(echo $issues | jq -r '.[] | [.content.title, .content.body] | @csv')

# Output the collected issues to a CSV file
echo "title,body" > project_issues.csv
echo "$csv_data" >> project_issues.csv

echo "Exported issues to project_issues.csv"