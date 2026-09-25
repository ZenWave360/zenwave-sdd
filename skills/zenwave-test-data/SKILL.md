---
name: zenwave-test-data
description: Generate or refresh the test data of a ZenWave-generated Spring Boot + JPA backend - src/test/resources/data.sql for the repository integration tests and src/test/resources/data/jpa/<Entity>/<n>.json for the in-memory service tests - from the DDL Hibernate actually runs, the ZDL lifecycles and the ZFL flows, so both files agree with each other and cover every state the commands need. Use after (re)generating code, after changing ZDL entities, or when data.sql / fixture JSON is missing, stale or fails to load.
---

# ZenWave Test Data

ZenWave generates `data.sql` and one stub `data/jpa/<Entity>/1.json` per entity
**once** (`skipOverwrite`). After that they belong to the developer and are *not*
updated when the model changes. This skill (re)writes them.

Work from three inputs, each authoritative for one thing:

| Input | Authoritative for |
|---|---|
| **DDL** (`target/ddl/schema.sql`) | table and column names, types, `not null`, `unique`, enum `check` values, sequence names and increments, `jsonb` / `array` columns |
| **JPA entity classes** (`src/main/**/domain/*.kt|java`) | JSON property names for the fixture files and for the contents of `jsonb` columns (Jackson uses property names, not `@Column` names) |
| **ZDL + ZFL** | which lifecycle states must exist (`@transition(from: ...)`), and how records chain across bounded contexts (shared business keys such as `orderId`, `sku`, `customerId`) |

Never derive column or sequence names from entity names yourself. Read them from the DDL.

## 1. Get the DDL

Use the bundled script from the project root. It needs Docker and the project's JDK:

```bash
bash <this skill>/scripts/export-ddl.sh                 # -> target/ddl/schema.sql
bash <this skill>/scripts/export-ddl.sh -t OrderRepositoryIntegrationTest -o /tmp/schema.sql -- -o
#                                        test to boot    output file         extra maven args (offline)
```

It boots one repository integration test with the JPA schema-generation settings
passed as `-D` system properties (Surefire forwards them to the test JVM, and they
override `application-*.yml`). **The project needs no configuration for this.** The
settings it passes:

```text
spring.jpa.properties.jakarta.persistence.schema-generation.database.action=drop-and-create
spring.jpa.properties.jakarta.persistence.schema-generation.scripts.action=create
spring.jpa.properties.jakarta.persistence.schema-generation.scripts.create-target=<absolute path>
spring.jpa.properties.hibernate.hbm2ddl.schema-generation.script.append=false
spring.jpa.properties.hibernate.hbm2ddl.delimiter=;
spring.jpa.properties.hibernate.format_sql=true
```

- `database.action` must be set explicitly: once any schema-generation action is
  set, Hibernate stops applying `ddl-auto`, and the tables wouldn't be created.
- The script is written while the `EntityManagerFactory` starts, **before**
  `data.sql` runs, so you get the DDL even when the current `data.sql` is broken
  or empty. A test failure after that point is expected and harmless.
- If no DDL is written, the context failed earlier (compile errors, Docker/DB
  connection). The script prints the first causes from `target/export-ddl.log`.
- Before using the DDL, check it isn't stale: every `@Entity` in `src/main` has a
  table, and new ZDL fields appear as columns. A missing column usually means that
  module wasn't regenerated.
- Ignore framework tables (Spring Modulith `event_publication`, Spring Batch, etc.).

## 2. Design the scenarios before writing rows

Don't aim for "one row per table". Aim for **one row per precondition state that a
command or test needs**, and keep the rows consistent across bounded contexts.

1. For each aggregate, list the states that appear in any `@transition(from: ...)`
   and in any flow step. Each one needs at least one row (e.g. Order `CREATED` for
   `confirmOrder`; Payment `FAILED` for `retryPayment`; Payment `AUTHORIZED` for
   `capturePayment`/`voidPayment`; an inventory position with 0 available for the
   "stock unavailable" branch).
2. Group the rows into **scenario chains** that follow the ZFL, keyed by business
   ids (`ORD-001`, `SKU`, `CUST-001`…). Every aggregate in a chain must be in a
   state that is reachable at the same point of the flow. For example, an order
   `CONFIRMED` implies its reservations are `CONFIRMED`, its payment is
   `AUTHORIZED` or later, and its fulfillment is `SCHEDULED` or absent.
3. Row 1 of every table must exist and be valid. Generated repository tests call
   `findById(1)`.
4. Respect every `unique` column in the DDL (e.g. `payment.order_id` unique means
   one payment per order across all chains).
5. Write the scenario matrix as the header comment of `data.sql`:
   `chain | business ids | state per aggregate | used by (command/test)`.

## 3. Write `data.sql`

- One `INSERT` per row, grouped by bounded context. Within a table, insert rows in
  the same order as the JSON fixture numbering.
- **Ids:** `nextval('<sequence from DDL>')`. With `increment by N` (Hibernate's
  default is 50), the k-th row inserted into a table gets id `1 + (k-1)*N`
  (1, 51, 101…). Use exactly those ids in the JSON fixtures. Later
  Hibernate-generated ids won't collide.
- `version` = `0`.
- List columns explicitly, using the DDL column names. Fill every `not null`
  column. Fill optional columns when the state implies them (e.g. `confirmed_at`
  for `CONFIRMED`), and leave them `NULL` when the state excludes them.
- **Enums:** use one of the values in the column's `check (... in (...))` constraint
  (`EnumType.STRING`). Only use integers if the DDL column is numeric (enum with ids
  and a converter).
- **Timestamps:** fixed ISO literals (`'2026-09-26T13:00:00Z'`), never
  `CURRENT_TIMESTAMP`, so the JSON can repeat the same value. Keep them
  chronologically consistent within a chain (`created_at` ≤ `confirmed_at`, and
  `expires_at` = `reserved_at` + the window the ZFL states).
- **`jsonb` columns** (`@json` embedded types): a JSON literal cast with
  `::jsonb`, using the embedded class's **Kotlin/Java property names** (camelCase,
  e.g. `unitPrice`), not its `@Column` names.
- **Array columns** (`varchar array`, `text[]`…): `ARRAY['a','b']`, or
  `'{}'` / `NULL` when empty.
- `numeric(p,s)`: plain decimal literal (`49.99`).
- Foreign keys (if any): insert parents first and reference their computed ids.
- Keep the header short: purpose, how to regenerate (this skill), the DDL date, and
  the scenario matrix. Don't paste generation prompts into the file.

## 4. Write the JSON fixtures

`src/test/resources/data/jpa/<EntitySimpleName>/<k>.json`, one file per row, where
`k` is the row's position in its table (1, 2, 3…). The **values are identical to
`data.sql`**:

- `id` = the computed sequence id for that row (1, 51, 101…); `version` = 0.
- Property names = entity property names (`orderId`, `customerEmail`), **not**
  column names.
- Embedded `@json` values are nested objects/arrays. Enums are their names.
  Instants are ISO strings. Decimals are numbers.
- Only aggregate/entity classes get fixture folders. Older ZenWave SDK versions
  also create stub folders for `@embedded` and other non-aggregate types (e.g.
  `OrderItem/`, `ShippingAddress/`). Delete them, because embedded values live
  inside their owner's JSON.

The in-memory `ServicesInMemoryConfig.reloadTestData()` loads these files with
Jackson into the entity classes, so an unknown or misspelled property fails the
service tests.

## 5. Validate

```bash
# data.sql against the real schema (Docker)
mvn -Dtest='*RepositoryIntegrationTest' -Dsurefire.failIfNoSpecifiedTests=false test
# JSON fixtures through Jackson / in-memory repositories
mvn -Dtest='*ServiceTest' -Dsurefire.failIfNoSpecifiedTests=false test
```

- Repository tests must pass with the new data. A failure in `data.sql` shows up as
  `dataSourceScriptDatabaseInitializer` / `ScriptStatementFailedException`, with the
  failing statement.
- Service tests may still fail because of *unimplemented behavior*. That's fine,
  but none may fail while **loading** fixtures (`Error reading json test data`).
- Cross-check SQL against JSON: same number of rows per table, same ids, same
  business keys.
- Known failures that are not caused by the data: the generated repository
  `updateTest` asserts `assertEquals(Instant.now(), updated.<instantField>)`, so it
  fails for every entity with an `Instant` field.
- A forced regeneration (`-f`) overwrites generated-once files, including
  `DockerComposeInitializer` (its `DATABASENAME` placeholder breaks the Testcontainers
  DB URL) and `data.sql`. Check `git diff` for them after regenerating.

## Refreshing after a model change

Update in place instead of rewriting. Keep existing chains and ids, add the new
columns/properties to every row, and add rows only for new states. Tests may
already reference existing business ids.
