# api contract

## send shared item

`POST /api/hermes/share`

headers:

```http
authorization: bearer <token>
content-type: application/json
```

payload:

```json
{
  "schema_version": "1.0",
  "destination": "coordinator",
  "agent_id": "default",
  "prompt": "optional user context prompt",
  "source": {
    "platform": "ios",
    "app": "safari",
    "share_extension_version": "0.1.0"
  },
  "content": {
    "type": "url",
    "title": "optional title",
    "url": "https://example.com",
    "text": "optional extracted text",
    "files": []
  },
  "client": {
    "request_id": "uuid",
    "created_at": "iso8601"
  }
}
```

## destinations

minimum:

- `coordinator`: send to general agent/coordinator chat/task creation
- `ingestion`: send to document/content ingestion pipeline

later:

- `research`
- `coding`
- `trading`
- custom agent ids discovered from backend

## response

```json
{
  "ok": true,
  "task_id": "optional",
  "message_id": "optional",
  "artifact_path": "optional",
  "status_url": "optional"
}
```

## error shape

```json
{
  "ok": false,
  "error": {
    "code": "unauthorized",
    "message": "human readable error"
  }
}
```
