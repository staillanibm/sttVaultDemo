curl -X POST "${ROOT_URL:-http://localhost:5555}/messages-api/messages" \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello world"}' -u Administrator:${ADMIN_PASSWORD:-manage}