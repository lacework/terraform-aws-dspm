# Examples

## Account-level Single Region

Deploys DSPM scanning infrastructure in a single AWS region. This is the simplest
configuration — use this when all the S3 buckets you want to scan are in one region.

See: [account-level-single-region/](./account-level-single-region/)

## Account-level Multi Region

Deploys DSPM scanning infrastructure across multiple AWS regions. Use this when you want to scan S3 buckets in more than one region. 
The `global_region` variable controls where shared resources (like the S3 output bucket) are created; it defaults to the first region in the `regions` list.

See: [account-level-multi-region/](./account-level-multi-region/)
