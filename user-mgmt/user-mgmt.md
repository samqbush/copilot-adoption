# User Management

Steps to setup and assign Copilot licenses for Teams in a Copilot Business Only enterprise:

- [Setup IDP integration](https://docs.github.com/en/enterprise-cloud@latest/admin/managing-iam/provisioning-user-accounts-with-scim/configuring-scim-provisioning-for-users#about-provisioning-for-enterprise-managed-users)
- [Create Enterprise Teams via API](https://docs.github.com/en/enterprise-cloud@latest/early-access/admin/articles/rest-api-endpoints-for-enterprise-teams)
- [Assign licenses to Users via Teams](https://docs.github.com/en/enterprise-cloud@latest/admin/copilot-business-only/setting-up-a-dedicated-enterprise-for-copilot-business-managed-users#assigning-licenses-to-users)
  - [Using the User Interface](https://docs.github.com/en/enterprise-cloud@latest/admin/copilot-business-only/setting-up-a-dedicated-enterprise-for-copilot-business-managed-users#assigning-licenses-to-a-team)
  - Using the API:
    - Find external/IDP ids using [API](https://docs.github.com/en/enterprise-cloud@latest/rest/enterprise-admin/scim?apiVersion=2022-11-28#list-provisioned-scim-groups-for-an-enterprise)
    - Update GitHub Enterprise team with group id using [API](https://docs.github.com/en/enterprise-cloud@latest/early-access/admin/articles/rest-api-endpoints-for-enterprise-teams#update-an-enterprise-team)
      - [Demo script for API](./idp-teams.sh)
