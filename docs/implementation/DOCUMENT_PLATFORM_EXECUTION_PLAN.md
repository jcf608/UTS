# Document Platform Execution Plan

_Status:_ Draft v0.1 — last updated 2025-11-17  
 _Owners:_ Platform Engineering Guild  
 _Source of Truth:_ Update this file **every session** so the next Cursor chat picks up exactly where the previous one stopped.
 
 ## 1. Objectives
 - Ship a document-centric RAG platform using Sinatra (REST), ActiveRecord/Postgres, Sidekiq workers, and a React/Vite UI.
 - Preserve the three-cloud strategy (Azure, AWS, GCP) for storage, decomposition, embeddings, and indexing.
 - Align with all `docs/PRINCIPLES.md` directives (DRY, fail-fast, multi-environment AI usage, documentation rigor, etc.).
 - Provide deterministic lifecycle management for documents: upload → SHA-256 versioning → decomposition → chunking → embeddings → indexing → publication.
 - Maintain auditable lineage, observability, and compliance-ready metadata for every document and processing step.
 
 ## 2. Living TODO / Kanban
 Update statuses (`todo` → `in_progress` → `blocked` → `done`) at the end of each session.
 
 | ID | Status | Owner | Description | Hand-off Notes |
 |----|--------|-------|-------------|----------------|
 | T1 | todo | Backend | Bootstrap monorepo structure (`apps/*`, `libs/*`, `db`, `config`, `infra`, `docs`). | Create base Gemfile, package.json, lint configs. |
 | T2 | todo | Backend | Configure Postgres + ActiveRecord (database.yml, connect scripts) and create initial migrations for core tables. | Include status enums + audit columns. |
 | T3 | todo | Backend | Implement domain models (`Document`, `DocumentVersion`, `DocumentChunk`, `ProcessingJob`) with state machine + SHA utilities. | Follow Principles §1 (DRY, single responsibility). |
 | T4 | todo | Backend | Build provider adapters + capability registry for Azure/AWS/GCP (storage, decomposer, embedder, indexer). | No fallback logic per Principles §9 & §20. |
 | T5 | todo | Backend | Implement Sinatra REST API (`/documents`, `/search`, `/admin`) with serialization helpers + error handling. | Ensure timestamps + pagination. |
 | T6 | todo | Backend | Stand up Sidekiq worker service + jobs (ingest, chunk, embed, index, retry) with idempotent pipeline orchestration. | Persist job telemetry. |
 | T7 | todo | Frontend | Scaffold React/Vite UI using Nordic palette + slide-out panels. Build pages: Upload, Document Detail, Search, Admin Dashboard. | Upload flow uses signed URLs + REST polling. |
 | T8 | todo | QA | Establish automated tests (RSpec/Minitest + Vitest) and enforce saved test outputs per Principles §11.6. | Add baseline test result filenames to `.gitignore`. |
 | T9 | todo | Ops | Add observability + infra (docker-compose, Terraform modules for tri-cloud, Sidekiq monitoring, log aggregation). | Document runbooks. |
 | T10 | todo | Docs | Keep this plan + `docs/PRINCIPLES.md` updated as architecture evolves; record ADRs + handoffs. | Each session logs date + summary. |
 
 > _Next Session Prep:_ Before closing a Cursor chat, append a short note under Section 12 (“Session Log”) describing what changed, tests run, and which TODO moved.
 
 ## 3. Architecture Snapshot
 - **Backend API:** Sinatra app (`apps/api`) exposing REST JSON endpoints. Uses ActiveRecord for persistence, JSON serializers for responses.
 - **Worker Service:** Sidekiq-based Rack app (`apps/worker`) that loads the same domain libs, processes lifecycle jobs, and emits events/logs.
 - **Domain & Providers:** Shared Ruby libs under `libs/domain` (entities, state machine, validations) and `libs/providers` (cloud adapters, capability registry).
 - **Pipelines:** `libs/pipelines` hosts service objects orchestrating document ingest, chunking, embedding, indexing, and search.
 - **Storage:** Postgres (metadata + chunk manifests), object storage per cloud for raw bytes and derived artifacts, pluggable vector DB(s).
 - **Frontend:** React/Vite client under `apps/frontend` communicating with REST API; adheres to Nordic palette + UX rules in `PRINCIPLES.md`.
 
 ## 4. Directory & File Expectations
 ```
 .
 ├── apps/
 │   ├── api/
 │   │   ├── config.ru
 │   │   ├── app.rb
 │   │   ├── routes/
 │   │   ├── middleware/
 │   │   ├── serializers/
 │   │   └── helpers/
 │   └── worker/
 │       ├── config.ru
 │       ├── boot.rb
 │       └── workers/
 ├── apps/frontend/ (Vite + React)
 ├── libs/
 │   ├── domain/
 │   │   ├── document.rb
 │   │   ├── document_version.rb
 │   │   ├── document_chunk.rb
 │   │   └── processing_job.rb
 │   ├── providers/
 │   │   ├── base_*.rb
 │   │   ├── azure/
 │   │   ├── aws/
 │   │   └── gcp/
 │   └── pipelines/
 ├── db/
 │   ├── migrate/
 │   ├── schema.rb
 │   └── seeds.rb
├── config/
 │   ├── database.yml
 │   ├── sidekiq.yml
 │   └── credentials templates
├── archive/
│   └── uts_legacy/            # Read-only snapshot or selected files from the original UTS repo
 ├── infra/
 │   ├── docker/
 │   ├── terraform/
 │   └── scripts/
 └── docs/
     └── implementation/
 ```
 
 ## 5. Phase Breakdown
 
 ### Phase 0 – Environment & Tooling
 - Initialize repo (gitignore, linting, formatting, CI workflows for Ruby/Node).
 - Add `.ruby-version`, `.tool-versions`, `.nvmrc`.
 - Ensure scripts follow `script/` hierarchy (Principles §1.1 & §11.7).
 - Deliverable: `bin/setup` script (Ruby) orchestrating bundle install, npm install, DB setup, `.env.example`.
 
 ### Phase 1 – Data Layer + Domain
 - Migrations for:
   - `documents` (id, title, status enum, preferred_provider, current_version_id, audit columns).
   - `document_versions` (document_id, storage_uri, sha256, mime_type, byte_size, uploader info).
   - `document_chunks` (version_id, chunk_uid, offset, text, embedding_vector pointer, provider_metadata JSONB).
   - `processing_jobs` (job_type, status, provider, attempts, error_log, ran_at timestamps).
   - `capability_registrations` (provider, capability_tag, supports_mime, region, latency_stats).
 - Implement ActiveRecord models with concerns for auditing + state transitions (Principles §1.4 & §2).
 - Add SHA-256 computation using streaming IO; guard rails for dedupe.
 - Tests: Model validations, associations, state machine transitions; save outputs (`test_results_phase1.txt`).
 
 ### Phase 2 – Provider & Capability Layer
 - Base adapter classes implementing template method for `store`, `retrieve`, `decompose`, `embed`, `index`.
 - Specific adapters under `providers/azure|aws|gcp` with capability tags (e.g., `:tables`, `:handwriting`, `:cad`).
 - Capability Registry service:
   - Discovers providers dynamically (no hardcoded lists; use config + DB per Principles §1.2).
   - Provides fallback order based on capability + region (still fail-fast if all fail).
 - Write contract tests for adapters (mock HTTP responses, ensure fail-fast).
 - Document configuration in `docs/features/multi_cloud_document_processing.md`.
 
 ### Phase 3 – Pipelines & Jobs
 - Service objects (`DocumentIngest`, `DocumentChunker`, `DocumentEmbedder`, `DocumentIndexer`, `DocumentSearch`, `DocumentRetry`).
 - Sidekiq jobs invoke service objects; ensure idempotency (check job tables before rerun).
 - Implement event emission (e.g., `DocumentEvents.emit(:chunked, document_id, metadata)`).
 - Observability: structured JSON logs, job metrics, error notifications.
 - Add manual scripts under `script/manual_tests/` for running pipeline end-to-end using sample documents.
 - Tests: Service specs + worker specs; store results file names.
 
 ### Phase 4 – Sinatra REST API
 - Middleware stack: auth placeholder, request logger, error translator (fail-fast per §9).
 - Routes:
   - `POST /documents` (create record + return signed upload URL).
   - `GET /documents/:id` (status, versions, provider usage, timestamps).
   - `POST /documents/:id/process` (enqueue ingest job).
   - `GET /documents/:id/chunks` (paginated chunk metadata).
   - `POST /search` (query, answer, supporting chunks).
   - `POST /documents/:id/retry`, `GET /capabilities`.
 - Serializer layer ensures timestamps + human-readable fields (Principles §3).
 - Add OpenAPI spec under `docs/api/openapi.yml`.
 - Tests: Rack::Test suite covering happy/sad paths.
 
 ### Phase 5 – React Frontend
 - Reuse existing Vite config; adopt Nordic palette + slide-out panel UX.
 - Components/pages:
   - `UploadPage` — collects metadata, hits `/documents`, PUTs file to signed URL, calls `/process`, shows progress.
   - `DocumentDetail` — timeline of statuses, chunk preview, provider usage; slide-out for chunk detail.
   - `SearchPage` — query input, displays answer + cited chunks; show provider + timestamp.
   - `AdminDashboard` — capability registry view, job queue stats, retry controls.
 - Hook modules: `useApiClient`, `useDocumentStatusPolling`.
 - Ensure UI never asks for IDs directly (Principles §3.1) and uses color palette guidelines.
 - Tests: Vitest for components, Cypress/Playwright optional for e2e smoke.
 
 ### Phase 6 – Infrastructure & Ops
 - Docker Compose for local (`sinatra`, `worker`, `postgres`, `redis`, `frontend`, `vector-db` placeholder).
 - Terraform/Bicep modules for deploying to Azure/AWS/GCP, referencing provider adapters.
 - Sidekiq monitoring, log aggregation, metrics export.
 - Runbooks in `docs/runbooks/*` for deploy, rollback, scaling, credential rotation.
 
 ### Phase 7 – QA, Migration, and Launch Prep
 - Import legacy data scripts (if needed) using Document APIs (Principles §19 – fix data, not logic).
 - Performance tests for chunking/embedding throughput.
 - Finalize documentation: ADRs, API reference, UX updates, `docs/history/` entry for completion.
 - Launch checklist referencing Principles §11.7 (tests/lints clean).
 
 ## 6. Data Model Cheatsheet
 - `documents`: `status` enum (`pending`, `ingested`, `chunked`, `embedded`, `indexed`, `published`, `failed`), `preferred_provider`, `current_version_id`, `search_index_ref`, `created_by_id`, `updated_by_id`, timestamps.
 - `document_versions`: `sha256`, `storage_uri`, `mime_type`, `byte_size`, `uploaded_by_id`, `source_cloud`, `ingested_at`.
 - `document_chunks`: `chunk_uid`, `offset_start`, `offset_end`, `text`, `embedding_pointer`, `metadata_jsonb`, `provider_used`.
 - `processing_jobs`: `job_type`, `status`, `attempts`, `provider`, `last_error`, `ran_at`, `document_id`, `document_version_id`.
 - `capability_registrations`: `provider`, `capability_tag`, `mime_patterns`, `region`, `latency_p50`, `latency_p95`, `last_verified_at`.
 
 ## 7. API Contract Highlights
 - **Headers:** `Accept: application/json`, `X-Request-Id`.
 - **Responses:** include `data`, `meta`, `included` (JSON:API-lite) with timestamps.
 - **Errors:** consistent shape `{ error: { code, message, remediation, timestamp } }`.
 - **Pagination:** `meta.pagination` with `page`, `per_page`, `total_pages`, `total_count`.
 - **Search Response:** `answer` text, `chunks` array (title, excerpt, document_id, provider, score), `latency_ms`.
 
 ## 8. Worker Pipeline Contracts
 - **IngestJob:** validates SHA-256, stores `DocumentVersion`, selects decomposer capability, enqueues `ChunkJob`.
 - **ChunkJob:** retrieves normalized payload, persists `DocumentChunk` rows, enqueues `EmbedJob`.
 - **EmbedJob:** batches chunks, calls embedder via provider registry, stores embedding pointers, enqueues `IndexJob`.
 - **IndexJob:** pushes to vector/keyword indices, updates `search_index_ref`, transitions document to `indexed`.
 - **RetryJob:** replays pipeline segments; ensures dedupe by checking job + document status.
 - All jobs log structured events (document_id, version_id, provider, duration) and emit Sidekiq metrics.
 
 ## 9. Frontend Experience Requirements
 - Use Nordic palette + typography from Principles §3.
 - Slide-out panels for create/edit/view tasks; modals only for blocking/error states.
 - Upload page shows SHA-256 + provider selection (if user-specified) and audit info.
 - Document detail highlights lifecycle timeline, cloud usage badges, chunk preview list, retry controls.
 - Search page surfaces answer plus chunk citations, provider icons, last indexed timestamp.
 - Admin dashboard exposes capability registry table + manual verification actions.
 
 ## 10. Observability & Compliance
 - Logging: JSON logs with `document_id`, `version_id`, `job_type`, `provider`, `request_id`.
 - Metrics: request durations, job durations, failure counts, per-provider throughput.
 - Audit trail: track `created_by`, `updated_by`, status changes, provider assignments (Principles §2).
 - Alerts: failure rate thresholds, queue latency, provider health checks.
 
 ## 11. Testing Strategy
 - Backend tests via RSpec/Minitest; use factories/helpers for documents + versions.
 - Provider adapters tested with VCR-style fixtures; ensure fail-fast behavior is covered.
 - Worker tests simulate Sidekiq jobs; confirm idempotency + event emission.
 - API tests snapshot JSON responses; verify pagination + error shapes.
 - Frontend tests with Vitest/RTL; e2e with Cypress (upload → process → search).
 - **Test Outputs:** Save every run to `test_results/*.txt` (Principles §11.6). Add path to `.gitignore`.
 
## 12. Session Log
Append a new bullet each time work is performed.
- _2025-11-17_ – Plan scaffolded; TODO list seeded. (Add a short summary when actual work begins.)
 
## 13. References
- `archive/uts_legacy/` — curated snapshot of the UTS source repo for reference only (no direct code execution).
- `docs/PRINCIPLES.md` — governing architectural principles (updated alongside this plan).
- `docs/features/multi_cloud_document_processing.md` — (to be created) details provider capabilities.
- `docs/runbooks/*` — operational procedures (pending).
- `scripts/manual_tests/*` — manual pipelines for QA (pending).
 
 ---
 
 _Reminder:_ This file **is the contract** for multi-session work. Treat updates as mandatory whenever tasks move, new decisions are made, or assumptions change.
