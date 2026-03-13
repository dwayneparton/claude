# Code Patterns in llm-api

## Provider Pattern
Each LLM provider has two layers:
1. **Registry Provider** (`models/<provider>.go`): implements `models.Provider` interface with prefix-based `Supports()`, prefix-stripping `CreateModel()`, and `Name()`
2. **ADK Adapter** (`internal/adk/model/<provider>/model.go`): implements `google.golang.org/adk/model.LLM` interface with `Name()` and `GenerateContent()`

## Constructor Convention
- `New*()` - stateless, no model name or account ID
- `New*WithContext()` - with modelName and accountID parameters
- Registry always calls `WithContext` with empty accountID (account ID comes from request pipeline)

## Account ID Flow
Account ID reaches the model through request config labels, not constructor params when using registry path:
1. REST: `convert.go` sets `config.Labels["account_id"]`
2. GraphQL agent: `adk/types/converters.go` sets it
3. Model adapters also have their own injection (for direct non-registry usage)

## Test Patterns
- Registry tests use `mockProvider`/`mockLLM` types in `registry_test.go`
- ADK adapter tests can use nil client for constructor/Name tests (client not dereferenced in constructor)
