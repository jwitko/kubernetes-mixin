# Fix newlines in PromQL queries for Grafana dashboards

This PR addresses an issue where newline characters in PromQL queries in JSON dashboard files were causing Grafana to return 500 errors. The solution involved:

1. Creating a Python script (`remove_all_newlines.py`) that recursively processes all dashboard JSON files to remove newlines from "expr" fields while maintaining valid JSON structure.

2. Modifying the Makefile to automatically run this script as part of the `generate` target, ensuring that all generated dashboards have clean PromQL queries.

3. Fixing the syntax in template variables and network metric queries in both `workload.libsonnet` and `workload-namespace.libsonnet` files.

4. Adding documentation to the README.md to explain the newline handling process.

These changes ensure that generated dashboard JSON files have properly formatted PromQL queries with no newline characters, preventing parsing errors in Grafana. 