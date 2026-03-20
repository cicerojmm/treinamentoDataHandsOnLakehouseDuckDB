Module `ecs-metabase-duckdb`
----------------------------

Deploys Metabase (Fargate) with an EFS-backed persistent volume for storing a `.duckdb` (or other persistent files). Exposes the service via an Application Load Balancer (public).

Important notes:
- The module creates an EFS filesystem and mount targets in the provided subnets.
- You must provide an ECR image URI for the Metabase image (`metabase` or a custom image that contains Metabase and any DuckDB plugins you need).
- The EFS mount is available inside the container at `/metabase-data`.
- Metabase default port `3000` is exposed through the ALB.

Usage (example in root `main.tf`): see module instantiation in repository `infra/terraform/main.tf`.
