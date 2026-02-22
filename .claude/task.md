plan mode


1. create terraform basic template, environment forlder with dev environment make sure to use s3 bucket for remote backend
2. module for cloudfront to host frontend from s3 bucket, vpc with 2 public subnet and 2 private4, s3, rds mysql community and an ecr module to for privater repos.
3. in dev env in main create s3 bucket for ui build store and use it top host on cloud front.