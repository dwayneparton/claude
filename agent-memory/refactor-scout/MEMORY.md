# Refactor Scout Memory

## Project: llm-api

### Architecture
- **Model Registry**: `models.Registry` with `Provider` interface (Supports/CreateModel/Name). Providers: OpenAI, Gemini.
- **ADK Adapters**: `internal/adk/model/openai/` and `internal/adk/model/gemini/` implement `google.golang.org/adk/model.LLM`
- **Two constructor pattern**: Each adapter has `New*()` (stateless) and `New*WithContext()` (with modelName, accountID). Registry uses `WithContext` variant with empty accountID.
- **Account ID injection**: Happens in 4+ places (REST convert layer, adk/types/converters, openai model inline, gemini injectAccountID helper). Prime dedup target.
- **Provider prefix stripping**: Both providers strip `"<provider>/"` prefix using `name[7:]` -- fragile magic number.
- **Import cycle constraints**: `models` pkg cannot import `adk/model/*` or `converters`. Registry wiring in `router.go`.

### Key File Paths
- `service/internal/models/` - Registry, providers, name constants
- `service/internal/adk/model/{openai,gemini}/` - ADK LLM adapters
- `service/internal/http/router.go` - Registry wiring, provider registration
- `service/internal/app/config.go` - Env config including API keys
- `service/internal/llm/response_service.go` - Legacy ResponseService (OpenAI-only, used by llmStream/llmCompletion resolvers)
- `service/internal/graph/resolvers/agent.resolvers.go` - Agent stream resolver using registry

### Duplication Hotspots
- account_id label injection (4 locations)
- Provider prefix stripping (models/openai.go, models/gemini.go)
- Stateless constructor variants (NewModel/NewResponsesModel) potentially dead code

### Patterns File
- See [patterns.md](patterns.md) for detailed code patterns
