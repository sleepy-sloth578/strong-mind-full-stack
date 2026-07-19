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

## How to verify it's working

1. **Build the images**

   ```bash
   docker compose build
   ```

   Completes without error.

2. **Start the long-running services**

   ```bash
   docker compose up --build
   ```

   - The `db` service becomes healthy.
   - The `worker` service boots the Solid Queue supervisor. You should see log
     lines like `SolidQueue-... Started Supervisor` and the worker stays running.
   - Leave this running in one terminal (or add `-d` to detach).

3. **Run one ingestion cycle** (in another terminal)

   ```bash
   docker compose run --rm ingest
   ```

   Prints:

   ```
   [ingest] starting one ingestion cycle
   ```

   and exits `0`.

4. **Run the tests**

   ```bash
   docker compose run --rm test
   ```

   Minitest runs

5. **Tear down**

   ```bash
   docker compose down -v
   ```