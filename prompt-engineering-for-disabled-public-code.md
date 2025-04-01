The following examples show how to prompt Copilot chat when public code suggestions are disabled in an enterprise/organization.

## Example 1 - pom.xml
**Bad**

- "Generate a pom.xml for this workspace"
- "Generate a pom.xml for this workspace without using public code"

**Good**

- "Generate a pom.xml for this workspace, but do not include the dependency or build section"
- "Add the dependency section to this pom.xml with the appropriate dependencies in this workspace"
- "Update/add the build section for this pom.xml using file xyz as an example"

## Example 2 - Generic review
**Bad**

- "How is the code quality in my file"

**Good**

- "How is the code quality in my file, but do not provide improvement samples"
