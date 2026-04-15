# iQuote v3 — RFQ Management System

## Project Overview

iQuote v3 is an automated equity derivatives pricing engine for RBC Capital Markets. Traders receive RFQs (Requests for Quote) from the STARS platform, price them using configurable strategies, and send the pricing results back to STARS.

This repo is the **RFQ management layer** — it receives RFQs from STARS, stores them in MongoDB, exposes a React UI for traders to view/price/send, and integrates with the existing iQuote v3 pricing engine (strategies repo + API repo).

## Architecture

```
STARS Platform
    │
    ▼ POST /api/rfqs (sends RFQ payload)
┌─────────────────────────────────────────────┐
│  iQuote v3 API  (FastAPI)                   │
│                                             │
│  /api/rfqs          → receive & store RFQs  │
│  /api/rfqs/{id}     → get RFQ details       │
│  /api/rfqs/{id}/price  → run strategy       │
│  /api/rfqs/{id}/send   → send to STARS      │
│  /api/strategies       → list available      │
│                                             │
│  Pricing Engine (existing):                 │
│    - Strategy registry (auto-discover)      │
│    - DataProvider SDK                       │
│    - Hierarchical settings (MongoDB)        │
│    - Dynamic GitHub strategy loading        │
│      (DEV/QA only)                          │
│                                             │
│  MongoDB: rfqs, raw_rfqs, settings          │
└─────────────────────────────────────────────┘
    │                           ▲
    ▼ POST (priced RFQ)        │
STARS Platform              React UI
                            (traders)
```

### Existing repos (context only, do not modify):

- **strategies repo**: traders build/test pricing strategies, push to GitHub
- **API repo**: FastAPI service that loads strategies from strategies repo on merge, runs them

### This repo structure:

```
iquote-rfq/
├── CLAUDE.md
├── backend/
│   ├── app/
│   │   ├── main.py              # FastAPI app, lifespan, CORS
│   │   ├── config.py            # Settings via pydantic-settings
│   │   ├── database.py          # MongoDB connection (Motor async)
│   │   ├── routers/
│   │   │   ├── rfqs.py          # RFQ CRUD + pricing + send
│   │   │   └── strategies.py    # List available strategies
│   │   ├── models/
│   │   │   ├── rfq.py           # RFQ document schema
│   │   │   └── pricing.py       # Pricing result schema
│   │   ├── services/
│   │   │   ├── rfq_service.py       # RFQ business logic
│   │   │   ├── pricing_service.py   # Strategy resolution + execution
│   │   │   └── stars_service.py     # STARS API client
│   │   └── utils/
│   │       └── raw_capture.py   # Raw request capture utilities
│   ├── requirements.txt
│   └── Dockerfile
├── frontend/
│   ├── src/
│   │   ├── App.jsx
│   │   ├── main.jsx
│   │   ├── api/
│   │   │   └── client.js        # Axios instance + API functions
│   │   ├── components/
│   │   │   ├── RFQDashboard.jsx     # Main table view
│   │   │   ├── RFQDetail.jsx        # Detail + pricing view
│   │   │   ├── PricingResult.jsx    # Pricing results display
│   │   │   ├── StrategyPicker.jsx   # Strategy selection dropdown
│   │   │   └── StatusBadge.jsx      # Color-coded status badges
│   │   ├── hooks/
│   │   │   └── useRFQs.js       # Data fetching hooks
│   │   └── styles/
│   │       └── index.css        # Tailwind + custom styles
│   ├── package.json
│   ├── vite.config.js
│   └── Dockerfile
└── docker-compose.yml
```

## Tech Stack

### Backend

- **Python 3.11+**
- **FastAPI** with async endpoints
- **Motor** (async MongoDB driver)
- **MongoDB** for RFQ storage
- **Pydantic v2** for validation
- **httpx** for async HTTP calls (STARS API)
- **pydantic-settings** for config

### Frontend

- **React 18** with functional components + hooks
- **Vite** for bundling
- **Tailwind CSS** for styling
- **Axios** for API calls
- **React Router v6** for navigation
- **React Query (TanStack Query)** for server state management

-----

## RFQ Status Lifecycle

Two collections, two separate lifecycles:

### `raw_rfqs` — Capture/Debug (Phase 1a only)

Status is always `raw`. No lifecycle. These are raw diagnostic dumps of what STARS sends. Once the STARS payload format is understood and the parser is built, this collection becomes an archive/audit log.

### `rfqs` — Production Lifecycle (Phase 1b onward)

Five statuses. Each transition maps to exactly one API call (`price` or `send`):

```
received ──→ priced ──→ sent ✓
   │            │
   ▼            ▼
 failed    send_failed
   │            │
   └──→ priced ─┘──→ sent ✓
     (retry)      (retry)
```

**Transition rules (enforce in service layer):**

- `POST /rfqs/{id}/price` → allowed when status is `received` or `failed`
- `POST /rfqs/{id}/send` → allowed when status is `priced` or `send_failed`
- Any other transition is rejected with 409 Conflict

**Status definitions:**

- `received` — RFQ parsed and stored, awaiting pricing
- `priced` — strategy executed successfully, pricing result stored, ready to send
- `sent` — pricing sent to STARS successfully (terminal state)
- `failed` — pricing execution crashed (retryable via price endpoint)
- `send_failed` — STARS API call failed (retryable via send endpoint)

-----

## Development Phases

### Phase 1a — Raw RFQ Capture (CURRENT PRIORITY)

**Goal:** Deploy an endpoint that accepts ANY request from STARS, stores the raw data, and lets us inspect what STARS actually sends.

**Endpoint:** `POST /api/rfqs/raw`

**Behavior:**

1. Read the raw `Request` object — headers, content-type, body bytes
1. Attempt JSON decode; if it fails, base64-encode the binary body
1. If content-type indicates a zip/gzip stream, store as binary and also attempt decompression
1. Store everything in `raw_rfqs` MongoDB collection
1. Return `{ "id": "<inserted_id>", "body_type": "json" | "binary" | "gzip" }`
1. Add a `GET /api/rfqs/raw` endpoint to list all captured raw RFQs (for debugging)
1. Add a `GET /api/rfqs/raw/{id}` endpoint to inspect a specific raw RFQ

**MongoDB `raw_rfqs` collection document:**

```json
{
  "_id": "ObjectId",
  "headers": { "content-type": "...", "...": "..." },
  "content_type": "application/json | application/octet-stream | ...",
  "body_type": "json | binary | gzip",
  "payload": {},             // parsed JSON if body_type is json
  "raw_base64": "...",       // base64-encoded raw bytes if binary
  "decompressed_payload": {},// if gzip, attempt decompress and parse
  "raw_size_bytes": 1234,
  "received_at": "2026-04-14T10:00:00Z",
  "status": "raw",
  "notes": ""                // manual notes field for debugging
}
```

**Important:** The endpoint must NOT reject any request format. No Pydantic model validation on the incoming body. Use `async def receive_rfq(request: Request)` directly.

-----

### Phase 1b — RFQ Parser & Clean Schema

**Goal:** After inspecting raw STARS data, build a parser that transforms it into a clean RFQ document.

**This phase is blocked until we inspect Phase 1a results.** Do not implement until we know the STARS payload format.

**MongoDB `rfqs` collection document (target schema):**

```json
{
  "_id": "ObjectId",
  "raw_rfq_id": "ObjectId",         // link to raw_rfqs document
  "stars_rfq_id": "string",         // STARS' own ID for this RFQ
  "underlying": "AAPL",
  "desk": "us_single_stock",
  "payoff_type": "vanilla_call",
  "side": "buy | sell",
  "strike": 200.0,
  "expiry": "2026-12-19",
  "notional": 1000000,
  "extra_params": {},
  "status": "received | priced | sent | failed | send_failed",
  "received_at": "2026-04-14T10:00:00Z",
  "priced_at": null,
  "sent_at": null,
  "pricing_result": null,            // populated after pricing
  "strategy_used": null,             // strategy ID or name
  "strategy_commit_sha": null,       // audit trail
  "error": null,                     // error message if failed
  "trader_id": null                  // who triggered pricing
}
```

**Parser service:** `services/rfq_service.py` will have a `parse_raw_rfq(raw_doc) -> RFQ` function. This is where STARS-specific field mapping lives — isolated, easy to update when the STARS format changes.

-----

### Phase 2 — Pricing Execution

**Goal:** Wire the RFQ into the existing pricing engine.

**Endpoint:** `POST /api/rfqs/{id}/price`

**Request body:**

```json
{
  "strategy_id": "eurp_option",    // optional — if null, auto-detect
  "trader_id": "trader_john"       // who is requesting the pricing
}
```

**Behavior:**

1. Load the RFQ document from MongoDB by ID
1. Validate status is `received` or `failed` (allow re-pricing on failure)
1. Resolve strategy:
- If `strategy_id` is provided → use that strategy (validate it exists in registry)
- If `strategy_id` is null → auto-detect from `desk` + `payoff_type` using existing registry
1. Build `PricingContext` using `DataProvider` SDK (market data, risk data, settings)
1. Execute strategy’s `compute_shift` / `price` method
1. Write result back to the RFQ document:
   
   ```json
   {
     "pricing_result": {
       "mid_price": 12.50,
       "bid_price": 12.30,
       "ask_price": 12.70,
       "shifts_applied": { "vol_shift": 0.02, "delta_shift": -0.005 },
       "greeks": { "delta": 0.55, "gamma": 0.03, "vega": 0.12 },
       "metadata": {}
     },
     "strategy_used": "eurp_option",
     "strategy_commit_sha": "abc123",
     "priced_at": "2026-04-14T10:05:00Z",
     "status": "priced",
     "trader_id": "trader_john"
   }
   ```
1. If pricing fails, set `status: "failed"` and store error message

**Endpoint:** `GET /api/strategies`

Returns list of available strategies from the registry with their desk, payoff_type, and description. Used by the frontend strategy picker dropdown.

-----

### Phase 3 — Send to STARS

**Goal:** Send the priced RFQ back to STARS via API call.

**Endpoint:** `POST /api/rfqs/{id}/send`

**Behavior:**

1. Load RFQ from MongoDB, validate status is `priced`
1. Build the JSON payload from `pricing_result` (format TBD — start with our internal JSON structure)
1. Call STARS API endpoint (URL from config: `STARS_API_URL`)
1. On success: update status to `sent`, store `sent_at` timestamp
1. On failure: update status to `send_failed`, store error, do NOT change `pricing_result`

**STARS client:** `services/stars_service.py` using `httpx.AsyncClient`. Keep it simple:

```python
async def send_to_stars(rfq: dict, pricing_result: dict) -> dict:
    payload = format_for_stars(rfq, pricing_result)  # adapt later
    response = await client.post(settings.STARS_API_URL, json=payload)
    response.raise_for_status()
    return response.json()
```

**Config:**

```
STARS_API_URL=https://stars.internal.rbc.com/api/quotes  # placeholder
STARS_API_TIMEOUT=30
```

-----

### Phase 4 — React Frontend

**Goal:** Trader-facing UI to view, price, and send RFQs.

**Design direction:** Industrial/utilitarian — this is a trading floor tool. Clean data density, monospace numbers, minimal chrome. Dark theme preferred (traders work in dark environments). Inspired by Bloomberg terminal aesthetics but with modern React ergonomics.

**Views:**

#### 4.1 — RFQ Dashboard (`/`)

- Table of all RFQs, sortable by received_at (newest first)
- Columns: STARS ID, Underlying, Desk, Payoff Type, Side, Strike, Expiry, Notional, Status, Received At, Actions
- Status badges with color coding:
  - `received` → blue
  - `priced` → amber/yellow
  - `sent` → green
  - `failed` → red
  - `send_failed` → orange
- Filter bar: status dropdown, date range picker, desk filter, search by underlying
- Auto-refresh every 30 seconds (React Query `refetchInterval`)
- Click row → navigate to detail view

#### 4.2 — RFQ Detail & Pricing (`/rfqs/:id`)

- Full RFQ details displayed clearly
- Strategy picker: dropdown listing available strategies from `GET /api/strategies`, with “Auto-detect” as default option
- “Price” button → calls `POST /api/rfqs/{id}/price`, shows loading state
- After pricing:
  - Display pricing result: mid/bid/ask prices (large, prominent numbers)
  - Shifts breakdown table
  - Greeks table
  - Strategy used + commit SHA (small, audit info)
- “Send to STARS” button (enabled only when status is `priced`)
- Status transitions visible in real-time

#### 4.3 — Raw RFQ Inspector (`/debug/raw`)

- Table of raw captured RFQs from Phase 1a
- Click to expand: show headers, content-type, body type, full payload
- This view is for development/debugging — can be hidden behind a feature flag later

**Component patterns:**

- Use React Query (`useQuery`, `useMutation`) for all API calls
- Optimistic updates for status changes
- Error toasts for failed operations
- Loading skeletons for data fetching states

-----

### Phase 5 — Polish (Future)

- WebSocket / SSE for real-time RFQ arrival notifications
- Batch pricing: select multiple RFQs, price all at once
- Manual price override before sending (trader adjusts bid/ask)
- Audit trail view: full history of who priced what, when, with which strategy
- RFQ analytics: volumes by desk, response times, strategy usage stats

-----

## API Endpoints Summary

|Method|Path                  |Description                  |Phase|
|------|----------------------|-----------------------------|-----|
|POST  |`/api/rfqs/raw`       |Capture raw STARS request    |1a   |
|GET   |`/api/rfqs/raw`       |List raw captured RFQs       |1a   |
|GET   |`/api/rfqs/raw/{id}`  |Inspect single raw RFQ       |1a   |
|GET   |`/api/rfqs`           |List parsed RFQs (filterable)|1b   |
|GET   |`/api/rfqs/{id}`      |Get single RFQ detail        |1b   |
|POST  |`/api/rfqs/{id}/price`|Price an RFQ                 |2    |
|POST  |`/api/rfqs/{id}/send` |Send pricing to STARS        |3    |
|GET   |`/api/strategies`     |List available strategies    |2    |

## Configuration (Environment Variables)

```env
# MongoDB
MONGODB_URI=mongodb://localhost:27017
MONGODB_DB_NAME=iquote_v3

# STARS Integration
STARS_API_URL=https://stars.internal.rbc.com/api/quotes
STARS_API_TIMEOUT=30

# Strategy Loading (existing)
LOAD_STRATEGIES_FROM_GITHUB=true   # false in PROD
STRATEGIES_REPO=org/iquote-strategies
GITHUB_TOKEN=***

# App
APP_ENV=dev                         # dev | qa | prod
API_PORT=8000
CORS_ORIGINS=["http://localhost:5173"]
LOG_LEVEL=INFO
```

## Coding Conventions

### Backend

- All endpoints are async
- Use Motor (async pymongo) — never blocking pymongo in async endpoints
- Pydantic v2 models for all API request/response schemas (except the raw capture endpoint)
- Use `from __future__ import annotations` in all files
- Type hints everywhere
- Service layer pattern: routers call services, services call database
- No business logic in routers — they only parse request, call service, return response
- Use `httpx.AsyncClient` for outbound HTTP calls, managed via app lifespan
- ObjectId serialization: convert to string in response models
- Timestamps in UTC (datetime.utcnow or datetime.now(UTC))
- Logging with structlog or standard logging — log every RFQ lifecycle transition

### Frontend

- Functional components only, no class components
- React Query for all server state — no manual useEffect + fetch patterns
- Tailwind CSS for styling — no CSS modules or styled-components
- Component files: PascalCase (RFQDashboard.jsx)
- Utility files: camelCase (client.js)
- Keep components under 200 lines — extract sub-components when they grow
- All API calls go through `api/client.js` — components never call fetch/axios directly

### Git

- Conventional commits: `feat:`, `fix:`, `refactor:`, `docs:`
- One phase per branch: `phase/1a-raw-capture`, `phase/1b-rfq-parser`, etc.

## Important Context

- This is a standalone app, separate from the existing iQuote v3 API repo and strategies repo
- The pricing engine integration (Phase 2) will either call the existing API repo’s endpoints or import its modules directly — decide based on deployment topology at RBC. For now, design the pricing service with an interface that can wrap either approach.
- STARS payload format is UNKNOWN at this point — that’s why Phase 1a exists. Do not make assumptions about field names or structure until we inspect real data.
- Traders are the primary users. Every UI decision should prioritize speed and clarity over aesthetics. No unnecessary clicks. Information density matters.
- This runs on the RBC internal network. No public internet access considerations.
