# hermes ios share

mvp scaffold for an iOS app + share extension that sends shared content to a user-configured Hermes agent endpoint

## goal

- appear in iOS share sheet
- accept url/text first, later files/images/pdf
- user chooses destination: coordinator or ingestion
- optional context prompt
- send structured JSON to Hermes-compatible backend
- no hardcoded Mo endpoint or secrets

## components

- `HermesShareApp/` SwiftUI host app
  - setup screen
  - endpoint + token config in Keychain
  - destination presets
  - send history / retry status

- `HermesShareExtension/` iOS share extension
  - receives share payload
  - normalizes url/text/file metadata
  - asks for destination + context prompt
  - posts JSON to configured endpoint

- `docs/api-contract.md`
  - backend payload contract

## suggested backend endpoints

```text
POST /api/hermes/share
POST /api/hermes/ingest
POST /api/hermes/message
```

for public/community use, the app should only require:

- base url
- bearer token or api key
- destination registry, either static or discovered from `/api/hermes/agents`

## build notes

this scaffold was created on linux, so it is source/template-level only
open/create the project in xcode on macos, add the share extension target, then copy the swift files into the matching targets
