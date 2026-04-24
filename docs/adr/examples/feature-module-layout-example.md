# Feature Module Layout Example

Illustrative shape for ADR 0007 (vertical feature modules) and ADR 0008 (barrel boundaries):

```text
packages/backend/src/chat/
  index.ts
  domain/
    index.ts
    ChatRequest.ts
    ChatSession.ts
  application/
    index.ts
    ChatService.ts
    ChatRepository.ts
  infrastructure/
    index.ts
    llm/
      index.ts
      LlmChatService.ts
    stub/
      index.ts
      StubChatRepository.ts
```

Notes:

- Other modules import from `chat/index.ts`, not deep paths into `chat/**`.
- Cross-layer imports use layer barrels (`domain/index.ts`, `application/index.ts`, `infrastructure/index.ts`).
- Category folders under `infrastructure/` expose small, intentional surfaces via their own `index.ts`.
