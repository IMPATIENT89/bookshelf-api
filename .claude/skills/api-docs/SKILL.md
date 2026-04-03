When generating API documentation:
1. Use OpenAPI 3.0 YAML format
2. For every endpoint include:
   - Method + path, Summary (one line)
   - Request body schema with examples
   - Response codes (200, 400, 404, 500) with example bodies
   - Query params for list endpoints
3. Group by resource
4. Include curl examples
5. Output to docs/api.yaml