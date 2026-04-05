# Small Focused Files Example

Illustrative guidance for ADR 0009:

Prefer one primary export per file:

```text
users/domain/
  User.ts
  UserId.ts
  UserEmail.ts
```

Keep related contracts together only when they are expected to evolve together:

```text
users/application/
  UserRepositoryContracts.ts
```

This keeps routine changes narrow while allowing deliberate "change together" exceptions.
