# Gateway contract fixtures

These JSON files are **golden fixtures** representing real (or best-guess) Gateway frames/payloads.
They are used by unit tests to validate decoding behavior without needing a live Gateway.

## Adding a new fixture

1. Add a `.json` file to this folder.
2. Add a decoding test in `Tests/HackPanelGatewayTests/*DecodingTests.swift`:
   - Use `FixtureLoader.decode(_:fromFixture:decoder:)`.
   - Assert on the decoded fields that matter.
3. Run `swift test`.

## Notes

- Some frames differ by Gateway version (e.g. `node.list` can be `{ "nodes": [...] }`, `{ "items": [...] }`, or directly `[ ... ]`). Add fixtures for each observed shape.
- `connect.challenge` fixture is aligned to the documented Gateway protocol shape (see `docs/gateway/protocol.md` in `openclaw/openclaw`). If a live capture differs, update `connect_challenge.json` + `GatewayFrameContractDecodingTests` accordingly.
