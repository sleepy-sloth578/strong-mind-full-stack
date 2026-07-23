# GitHub Push Event Ingestion Service

An internal service that ingests GitHub `PushEvent` activity from the public
events API, enriches each event with related actor and repository data, and
stores it in PostgreSQL for later querying and analysis.

**Stack:** Ruby on Rails 8 (API-only) · PostgreSQL · Solid Queue · Docker Compose.

## Requirements

- Docker Desktop (macOS)

## Commands

```bash
docker compose up --build       # start PostgreSQL + the Solid Queue worker (long-running)
docker compose run --rm ingest  # run one ingestion cycle, then exit
docker compose run --rm test    # run the test suite
```

## How it works


- **Long-running** (`docker compose up`): PostgreSQL + a Solid Queue **worker**.
- **On-demand** (`docker compose run --rm ingest`): one ingestion cycle, then exits.

```
ingest (on-demand)
  └─ GithubEventsClient.fetch        fetch the Github events
     │                               
     ├─ keep PushEvents
     ├─ persist raw + structured     RawEvent (source of truth) + PushEvent
     │                               (idempotent upserts)
     └─ EnrichStaleEntities          enqueue enrichment for stale repos/actors,
                                     up to the remaining rate budget
                                     │
worker (long-running)  ◄─────────────┘
  └─ EnrichRepositoryJob / EnrichActorJob
        fetch each entity url (GithubEntitiesClient),
        fill in details, mark fresh — skipping anything already fresh (cache)
```


## How to verify it's working

**1. Build**

```bash
docker compose build
```

**2. Start the long-running services** (Terminal 1)

```bash
docker compose up --build
```
- `db` becomes healthy.
- `worker` boots Solid Queue and stays running. Leave this terminal open.

**3. Run one ingestion cycle** (Terminal 2)

```bash
docker compose run --rm ingest
```
Prints a summary like:
```
[ingest] starting one ingestion cycle
[client] page 1: +100 events; remaining=59
...
[ingest] done in 4.5s — {:fetched=>293, :push_events=>95, :persisted=>95, :failed=>0, :enqueued=>49}
```
- `persisted` = push events stored (with repo/actor).
- `enqueued` = enrichment jobs queued (capped by the remaining rate budget).

**4. Watch enrichment happen** (back in Terminal 1)

```bash
docker compose logs -f worker | grep '\[enrich\]' # to filter
```
You'll see the worker draining the queue for example:
```
[enrich] actor octocat enriched
[enrich] repository rails/rails enriched
[enrich] actor somebot not found (404); marked attempted
```

**5. Inspect the data**

```bash
docker compose exec db psql -U postgres -d strong_mind_development -c "
  SELECT count(*) FROM push_events;
  SELECT count(*) FROM repositories WHERE fetched_at IS NOT NULL;  -- enriched repos
  SELECT full_name, language, stargazers_count FROM repositories
  WHERE fetched_at IS NOT NULL LIMIT 5;"
```

**6. Run the tests**

```bash
docker compose run --rm test
```
Minitest runs green (models, HTTP clients, ingest pipeline, enrichment jobs).

**7. Tear down**

```bash
docker compose down      # keeps the database volume
docker compose down -v   # also wipes the database
```

**7. Tear Down**

```bash
docker compose down -v
```

## Rate limits

The GitHub events API is used **unauthenticated** which means no token is used.
Github allows **60 requests/hour per IP** which is shared accross fetch and enrichment
