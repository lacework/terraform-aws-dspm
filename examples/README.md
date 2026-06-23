# Examples

## Account-level Single Region

Deploys DSPM scanning infrastructure in a single AWS region. This is the simplest
configuration — use this when all the S3 buckets you want to scan are in one region.

See: [account-level-single-region/](./account-level-single-region/)

## Account-level Multi Region

Deploys DSPM scanning infrastructure across multiple AWS regions. Use this when you want to scan S3 buckets in more than one region. 
The `global_region` variable controls where shared resources (like the S3 output bucket) are created; it defaults to the first region in the `regions` list.

See: [account-level-multi-region/](./account-level-multi-region/)

## Org-level Single Region

Deploys DSPM scanning for an entire AWS organization from one scanning account: the
scanner enumerates the org's accounts and assumes a read-only role in each to scan its
S3 buckets. Pairs `module.lacework_dspm` (`integration_level = "org"`) with the
`org-roles` submodule (run against the management account), which creates the org-read
role and the member-role StackSet. Requires the Lacework provider `>= 2.4`.

See: [org-level-single-region/](./org-level-single-region/)
