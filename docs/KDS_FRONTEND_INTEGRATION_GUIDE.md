# KDS Frontend Integration Guide

**Audience:** Flutter / frontend developers integrating against the live KDS backend (`KdsApi`).  
**Source of truth:** Current staging implementation (not the original planning spec).  
**Related (historical) doc:** `docs/BACKEND_KDS_INTEGRATION.md` — useful background, but several assumptions there no longer match what shipped. See [Differences from the original spec](#13-differences-from-the-original-spec).

JSON uses **camelCase** field names everywhere.

---

## 1. Base URL (staging)

| Environment | Base URL |
|-------------|----------|
| **Staging (use this now)** | `http://localhost:5088` |
| Production | *Not deployed yet — URL will be provided separately* |

All REST paths below are relative to that base, under `/api/v1/kds/...`.

WebSocket base (from config / bootstrap):

```text
ws://localhost:5088/api/v1/kds/ws
```

> Staging today runs locally against the staging Order Master DB. Treat `localhost:5088` as the **staging** endpoint for integration work, not production.

---

## 2. Required headers

### Login & refresh (exempt)

`POST /api/v1/kds/auth/login` and `POST /api/v1/kds/auth/refresh` do **not** require auth or the device/request headers below.

### Every other REST call under `/api/v1/kds/*` (except WebSocket)

| Header | Required | Notes |
|--------|----------|--------|
| `Authorization` | Yes | `Bearer <accessToken>` |
| `X-Device-Id` | Yes | Stable device UUID/string you generate and persist on the device |
| `X-Request-Id` | Yes | Unique per HTTP request (for tracing); generate a new one each call |
| `Content-Type` | For bodies | `application/json` |

Missing auth → `401` with code `UNAUTHORIZED`.  
Missing `X-Device-Id` or `X-Request-Id` → `400` with code `VALIDATION_ERROR`.

WebSocket uses query params / Bearer token instead of these headers (see [§11](#11-websocket)).

---

## 3. Auth flow

### 3.1 Login

`POST /api/v1/kds/auth/login`

**Request**

```json
{
  "restaurantId": "rest_001",
  "outletId": "outlet_main",
  "staffId": "staff_12",
  "pin": "1234",
  "deviceId": "kds-device-uuid-stable"
}
```

| Field | Format / notes |
|-------|----------------|
| `restaurantId` | `rest_` + zero-padded CID, e.g. `rest_001` |
| `outletId` | Currently the configured default is `outlet_main` (send this) |
| `staffId` | `staff_` + numeric staff id, e.g. `staff_12` |
| `pin` | Staff PIN (plain string) |
| `deviceId` | Same stable id you will send as `X-Device-Id` after login |

**Success `200`**

```json
{
  "accessToken": "<jwt>",
  "refreshToken": "<jwt>",
  "expiresAt": "2026-08-08T12:30:00Z",
  "staff": {
    "id": "staff_12",
    "name": "Jane Doe",
    "initials": "JD",
    "roles": ["kds_operator"]
  },
  "restaurant": {
    "id": "rest_001",
    "name": "Order Master"
  },
  "outlet": {
    "id": "outlet_main",
    "name": "Main Restaurant"
  }
}
```

- Access token lifetime (staging config): **30 minutes**.
- Refresh token lifetime (staging config): **7 days**.
- Role is always `kds_operator` when `Staff.AllowKds = 1`.

### 3.2 Device auto-registration (important)

On **first successful login**, the backend **automatically registers** the `deviceId` with `IsAllowed = 1` and no station assigned.

- There is **no approval / pending step**.
- Do **not** build UI or polling for “waiting for device approval”.
- `DEVICE_NOT_ALLOWED` only happens if an existing device row was manually set to `IsAllowed = 0` (kill-switch), or on refresh if the device row is missing / blocked.

### 3.3 No PIN lockout (important)

Wrong PIN always returns `401 INVALID_PIN`. There is **no** temporary lockout after N failures.

- Do **not** build lockout countdowns or “try again in X minutes” UI based on failed attempts.
- (`STAFF_LOCKED` exists in shared error helpers but is **not** returned by the current login path.)

### 3.4 Refresh

`POST /api/v1/kds/auth/refresh`

```json
{
  "refreshToken": "<jwt>",
  "deviceId": "kds-device-uuid-stable"
}
```

**Success `200`**

```json
{
  "accessToken": "<jwt>",
  "expiresAt": "2026-08-08T13:00:00Z"
}
```

Refresh does **not** rotate the refresh token. `deviceId` must match the device claim on the refresh token.

### 3.5 Suggested first-run flow

1. Persist a stable `deviceId` on the tablet.
2. Login with restaurant / outlet / staff / PIN / `deviceId`.
3. Store `accessToken`, `refreshToken`, `expiresAt`, staff, restaurant, outlet.
4. Call **bootstrap**.
5. Show station picker from bootstrap `stations`.
6. Call **`PUT /devices/me/station`** to save the chosen default (optional but recommended for UX).
7. Load active orders for that station + open WebSocket for that station.

---

## 4. Station selection (non-enforced default)

`PUT /api/v1/kds/devices/me/station`

**Headers:** auth + `X-Device-Id` + `X-Request-Id`

**Body**

```json
{
  "stationId": "station_grill"
}
```

**Success `200`**

```json
{
  "deviceId": "kds-device-uuid-stable",
  "stationId": "station_grill",
  "stationName": "Grill"
}
```

### Semantics

This stores the device’s **preferred / default station only**.

- It does **not** restrict which station the app may load orders for.
- It does **not** block WebSocket connections or order actions for other stations.
- Orders APIs still require an explicit `stationId` query/body each time — use whatever station the operator is currently viewing.

Use it so the app can reopen on the last-selected station after relaunch.

---

## 5. Bootstrap

`GET /api/v1/kds/bootstrap?restaurantId=rest_001&outletId=outlet_main`

**Success `200`**

```json
{
  "serverTime": "2026-08-08T12:00:00Z",
  "restaurant": { "id": "rest_001", "name": "Order Master" },
  "outlet": { "id": "outlet_main", "name": "Main Restaurant" },
  "stations": [
    {
      "id": "station_grill",
      "name": "Grill",
      "displayOrder": 1,
      "isActive": true
    }
  ],
  "categories": [
    { "id": "cat_5", "name": "Mains", "sortOrder": 1 }
  ],
  "products": [
    {
      "id": "prod_100",
      "name": "Burger",
      "categoryId": "cat_5",
      "stationIds": ["station_grill"],
      "isActive": true
    }
  ],
  "websocket": {
    "url": "ws://localhost:5088/api/v1/kds/ws",
    "heartbeatIntervalSeconds": 20,
    "reconnectMinDelayMs": 500,
    "reconnectMaxDelayMs": 10000
  }
}
```

Use `stations` for the picker. Prefer the `websocket.url` and `heartbeatIntervalSeconds` from bootstrap rather than hardcoding.

---

## 6. Orders

### ID formats (opaque strings)

| ID | Example shape | Client rule |
|----|---------------|-------------|
| `orderId` | `ord_12345:station_grill` | **Opaque.** Echo exactly as received. Never parse or construct. |
| `itemId` | `item_987:station_grill` | **Opaque.** Echo exactly as received. Never parse or construct. |
| `sourceOrderId` | `ord_12345` | Display/debug only if needed |
| `sourceItemId` | `item_42` | Display/debug only if needed |
| `stationId` | `station_grill` | From bootstrap / order payload |
| `productId` | `prod_100` | From bootstrap / item payload |

> The numeric parts and `:station_` suffix are server conventions. **Do not** build `orderId`/`itemId` on the client — always use values from list/bootstrap/events/action responses.

### 6.1 List orders

`GET /api/v1/kds/orders?restaurantId=rest_001&outletId=outlet_main&stationId=station_grill&status=active`

| Query | Notes |
|-------|--------|
| `restaurantId` | Required |
| `outletId` | Required by route contract (send `outlet_main`) |
| `stationId` | Required — station currently displayed |
| `status` | `active` (default) or `completed` |
| `limit` | Optional. Defaults: active **200**, completed **50** |

**Active** = statuses `newOrder`, `cooking`, and `cancelled`, oldest first.  
**Completed** = status `completed` from roughly the last **2 hours**, newest first.

Cancelled tickets stay on the active board so the kitchen can see a pull — they are **not** deleted and are **not** signaled with `order.removed`.

**Success `200`**

```json
{
  "serverTime": "2026-08-08T12:00:00Z",
  "stationId": "station_grill",
  "syncCursor": "cursor_42",
  "orders": [
    {
      "id": "ord_12345:station_grill",
      "sourceOrderId": "ord_12345",
      "displayNumber": "A12",
      "kotNumber": "A12",
      "restaurantId": "rest_001",
      "outletId": "outlet_main",
      "stationId": "station_grill",
      "createdAt": "2026-08-08T11:55:00Z",
      "updatedAt": "2026-08-08T11:56:00Z",
      "completedAt": null,
      "type": "dineIn",
      "status": "newOrder",
      "tableNumber": "5",
      "customerName": null,
      "note": "No onions",
      "version": 1,
      "items": [
        {
          "id": "item_987:station_grill",
          "sourceItemId": "item_42",
          "productId": "prod_100",
          "nameSnapshot": "Burger",
          "quantity": 1,
          "modifierText": "Medium",
          "note": null,
          "isCompleted": false,
          "isNew": false,
          "sortOrder": 0
        }
      ]
    }
  ]
}
```

Persist `syncCursor` for reconnect/sync.

**Order `type` values:** `dineIn` | `takeOut` | `delivery`  
**Order `status` values you will see on tickets:** `newOrder` | `cooking` | `completed` | `cancelled`

### 6.2 Start / complete / rollback

All three share the same body shape.

| Action | Method / path | Allowed from → to |
|--------|---------------|-------------------|
| Start | `POST /api/v1/kds/orders/{orderId}/start` | `newOrder` → `cooking` |
| Complete | `POST /api/v1/kds/orders/{orderId}/complete` | `cooking` → `completed` |
| Rollback | `POST /api/v1/kds/orders/{orderId}/rollback` | `completed` → `cooking` |

Optional query: `?restaurantId=rest_001` (otherwise taken from JWT `cid` claim).

**Body (`OrderActionRequest`)**

```json
{
  "stationId": "station_grill",
  "staffId": "staff_12",
  "deviceId": "kds-device-uuid-stable",
  "idempotencyKey": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "expectedVersion": 1,
  "reason": null
}
```

| Field | Notes |
|-------|--------|
| `stationId` | Must match the order’s station |
| `staffId` | Logged-in staff external id |
| `deviceId` | Same as `X-Device-Id` |
| `idempotencyKey` | UUID; reuse on retries of the **same** user action |
| `expectedVersion` | Current `order.version` you last saw |
| `reason` | Optional; unused by current transitions |

**Success `200`**

```json
{
  "order": {
    "id": "ord_12345:station_grill",
    "status": "cooking",
    "version": 2,
    "updatedAt": "2026-08-08T12:01:00Z",
    "completedAt": null
  }
}
```

If start is called when the order is **already** `cooking`, success returns with `"alreadyApplied": true` and the current summary (no version bump).

Invalid transition → `409 INVALID_TRANSITION` with `details.currentStatus`.

### 6.3 Item PATCH (complete / uncomplete, or acknowledge removed)

`PATCH /api/v1/kds/orders/{orderId}/items/{itemId}?restaurantId=rest_001`

Same route serves two actions:

#### A) Toggle complete (active lines only)

```json
{
  "stationId": "station_grill",
  "isCompleted": true,
  "staffId": "staff_12",
  "deviceId": "kds-device-uuid-stable",
  "idempotencyKey": "8f14e45f-ceea-467c-9a7e-8c7b0a1b2c3d",
  "expectedVersion": 2
}
```

- Allowed **only** while order status is `cooking`.
- **Removed lines cannot be completed** — returns `400 VALIDATION_ERROR` (use acknowledge instead).
- Marking completed also clears `isNew` on that item server-side.

#### B) Acknowledge removed (`isRemovedUnseen` → false)

```json
{
  "stationId": "station_grill",
  "acknowledgeRemoved": true,
  "staffId": "staff_12",
  "deviceId": "kds-device-uuid-stable",
  "idempotencyKey": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "expectedVersion": 4
}
```

- Valid **only** when the item has `isRemoved: true`. Otherwise `400 VALIDATION_ERROR`.
- Clears `isRemovedUnseen` to `false`; leaves `isRemoved: true` and does **not** change `isCompleted`.
- Allowed while the order is on the active board (`newOrder`, `cooking`, or `cancelled`).
- This is the **only** valid item PATCH for a removed line.

**Success `200` (toggle example)**

```json
{
  "item": {
    "id": "item_987:station_grill",
    "isCompleted": true,
    "isRemoved": false,
    "isRemovedUnseen": false
  },
  "order": {
    "id": "ord_12345:station_grill",
    "status": "cooking",
    "version": 3,
    "updatedAt": "2026-08-08T12:02:00Z",
    "completedAt": null
  }
}
```

---

## 7. Item-level flags

| Field | Meaning | UI guidance |
|-------|---------|-------------|
| `isCompleted` | Kitchen marked this line done | Strike-through / checked. Toggle only in `cooking` on non-removed lines. |
| `isNew` | Line was **added after cooking started** (late add) | Highlight until kitchen acts — cleared when the item is completed. |
| `isRemoved` | Line was **removed after being sent to kitchen** | Keep on ticket with removed treatment (never silently omit). |
| `isRemovedUnseen` | Removed line still needs kitchen attention | Same persistence pattern as `isNew` (below). |

### `isNew` ↔ `isRemovedUnseen` (same pattern)

These are mirror concepts — reuse the same UI/state handling:

| | `isNew` | `isRemovedUnseen` |
|--|---------|-------------------|
| Set when | Line added after cooking started | Line marked removed (`isRemoved` becomes true) |
| Persists across | Reconnects / app restarts / missed WS delivery | Same |
| Cleared when | Item completed (`isCompleted: true`) | `acknowledgeRemoved: true` on item PATCH |
| Not cleared by | Time, reconnect, or passive delivery | Time, reconnect, or passive delivery |

So: if the chef’s screen wasn’t looking when the event arrived, or the app restarts, `isRemovedUnseen: true` still means “highlight this removed line until acknowledged,” just like `isNew: true` means “highlight this late add until completed.”

### Visibility of removed lines

Removed lines stay in `items[]` on **active** lists, **completed** history, and live `order.created` / `order.updated` / sync payloads, with `"isRemoved": true` and usually `"isRemovedUnseen": true` until acknowledged.

Do **not** treat a missing item as the removal signal — after a full-state replace, look for `isRemoved` / `isRemovedUnseen` and render accordingly.

---

## 8. Completing all items does **not** auto-complete the order

**Confirmed behavior:** toggling every item to `isCompleted: true` leaves the order in `cooking`.

The operator (or UI) must call:

```http
POST /api/v1/kds/orders/{orderId}/complete
```

with a valid `expectedVersion` after the last item patch. Do not assume the board will clear itself when the last checkbox is ticked.

---

## 9. Idempotency and version conflicts (`409`)

### Idempotency

For start / complete / rollback / item patch:

- Send a new UUID `idempotencyKey` for each **distinct** user action.
- On network retry of the **same** action, resend the **same** key + same body.
- Server caches the response per `(deviceId, idempotencyKey)` and returns the cached JSON on repeat (same HTTP success shape).

Empty/`00000000-0000-0000-0000-000000000000` keys are ignored (no caching). Prefer always sending a real UUID.

### Version conflict

If `expectedVersion` ≠ current server version:

**HTTP `409`**

```json
{
  "error": {
    "code": "VERSION_CONFLICT",
    "message": "Order was updated by another device.",
    "details": {},
    "currentVersion": 5
  },
  "order": {
    "id": "ord_12345:station_grill",
    "status": "cooking",
    "version": 5,
    "items": [ /* full current order */ ]
  }
}
```

**Frontend recovery**

1. Replace your local order with the `order` object from the 409 body (full state).
2. Update UI from that version.
3. If the user still wants the action, retry with the new `expectedVersion` (and a **new** idempotency key if it is a new attempt after conflict, not a transport retry of the original attempt).

Also handle `409 INVALID_TRANSITION` separately — that is a state-machine rejection, not a version race:

```json
{
  "error": {
    "code": "INVALID_TRANSITION",
    "message": "Cannot complete order from status 'newOrder'.",
    "details": { "currentStatus": "newOrder" }
  }
}
```

---

## 10. Sync since cursor (reconnect)

`GET /api/v1/kds/sync?restaurantId=rest_001&outletId=outlet_main&stationId=station_grill&cursor=cursor_42`

Call this when:

- WebSocket `server.hello` says `syncRequired: true`, or
- You reconnect after a gap and still have a last known cursor, or
- You want a catch-up without full list reload.

**Success `200`**

```json
{
  "serverTime": "2026-08-08T12:05:00Z",
  "events": [
    {
      "eventId": "evt_43",
      "type": "order.updated",
      "occurredAt": "2026-08-08T12:04:50Z",
      "stationId": "station_grill",
      "payload": { "order": { /* full order */ } }
    }
  ],
  "nextCursor": "cursor_43",
  "requiresFullReload": false
}
```

If `requiresFullReload` is `true`, discard partial catch-up and re-fetch `GET /orders?status=active` (and completed if needed), then reset your cursor from the list response’s `syncCursor`.

Apply each event the same way as WebSocket events (full replace, not merge). Persist `nextCursor`.

---

## 11. WebSocket

### Connect

URL from bootstrap, plus query params:

```text
ws://localhost:5088/api/v1/kds/ws
  ?restaurantId=rest_001
  &outletId=outlet_main
  &stationId=station_grill
  &deviceId=kds-device-uuid-stable
  &access_token=<accessToken>
```

Auth alternatives:

1. Query `access_token=...` (typical for Flutter), or  
2. HTTP `Authorization: Bearer <accessToken>` on the upgrade request.

Required query: `stationId`, `deviceId`, `restaurantId`. Invalid/missing → non-WS HTTP 400/401/404 (connection not upgraded).

### Client → server

After connect, send hello (include last cursor if you have one):

```json
{
  "type": "client.hello",
  "messageId": "hello_1",
  "lastCursor": "cursor_42"
}
```

Respond to every server `ping` with:

```json
{
  "type": "pong",
  "messageId": "<same as ping.messageId>",
  "clientTime": "2026-08-08T12:06:00Z"
}
```

If the server does not receive a pong within ~2× heartbeat interval, it closes the socket. Heartbeat interval is **20s** on staging (`websocket.heartbeatIntervalSeconds`).

### Server → client

**Hello reply**

```json
{
  "type": "server.hello",
  "messageId": "hello_1",
  "serverTime": "2026-08-08T12:06:00Z",
  "connectionId": "conn_abc123",
  "heartbeatIntervalSeconds": 20,
  "syncRequired": true,
  "cursor": "cursor_50"
}
```

If `syncRequired` is true, call `GET /sync` with your last cursor (or reload orders).

**Ping**

```json
{
  "type": "ping",
  "messageId": "ping_xxxxxxxx",
  "serverTime": "2026-08-08T12:06:20Z"
}
```

**Domain event envelope**

```json
{
  "type": "order.created",
  "eventId": "evt_51",
  "cursor": "cursor_51",
  "restaurantId": "rest_001",
  "outletId": "outlet_main",
  "stationId": "station_grill",
  "occurredAt": "2026-08-08T12:07:00Z",
  "payload": {
    "order": { /* full OrderDto-shaped object */ }
  }
}
```

### Event types implemented

| `type` | Payload | Client action |
|--------|---------|---------------|
| `order.created` | `{ "order": { ...full order... } }` | Insert/replace ticket by `order.id` |
| `order.updated` | `{ "order": { ...full order... } }` | **Replace** entire local ticket by `order.id` |

**Cancellations** arrive as `order.updated` with `"status": "cancelled"` and the full order (items intact). Keep the ticket visible with a clear Cancelled treatment — do **not** remove it from the board just because it was cancelled.

`order.removed` is **not** emitted by the current backend (and must not be assumed). There is no “silently erase ticket” event for POS cancels.

Example cancel payload (inside the usual WS envelope’s `payload`):

```json
{
  "order": {
    "id": "ord_12345:station_grill",
    "status": "cancelled",
    "version": 4,
    "items": [ /* full lines, including any with isRemoved: true */ ]
  }
}
```

### Full state, not deltas

`order.created` / `order.updated` carry a **full order object** (items included, **including** `isRemoved: true` lines). Always **replace** your local copy keyed by `order.id`. Do not deep-merge item lists — merging causes ghost lines and missed flag clears.

After applying an event, store `cursor` / `eventId` for the next reconnect sync.

---

## 12. Error envelope and codes

### Standard error body

Most API errors:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Human readable message.",
    "details": {}
  }
}
```

Version conflicts additionally include top-level `order` and `error.currentVersion` (see [§9](#9-idempotency-and-version-conflicts-409)).

### Codes you should handle

| HTTP | Code | When |
|------|------|------|
| 400 | `VALIDATION_ERROR` | Bad/missing params, headers, id format, station mismatch on body |
| 401 | `UNAUTHORIZED` | Missing/invalid/expired token; refresh device mismatch |
| 401 | `INVALID_PIN` | Wrong PIN on login |
| 403 | `STAFF_NOT_ALLOWED` | Unknown/inactive staff, or `AllowKds` not enabled |
| 403 | `DEVICE_NOT_ALLOWED` | Device hard-blocked (`IsAllowed=0`) or unknown on refresh / station save |
| 404 | `ORDER_NOT_FOUND` | Unknown `orderId` for restaurant |
| 404 | `ITEM_NOT_FOUND` | Unknown / wrong-station `itemId` |
| 404 | `STATION_NOT_FOUND` | Unknown or inactive station |
| 409 | `VERSION_CONFLICT` | Stale `expectedVersion` — body includes full `order` |
| 409 | `INVALID_TRANSITION` | Illegal status/action (details may include `currentStatus`) |

`STAFF_LOCKED` (`423`) is defined in shared helpers but **not emitted** by current login (no PIN lockout). Ignore for UI planning unless a future release re-enables it.

---

## 13. Differences from the original spec

Plain list of places the **built** system differs from assumptions in `BACKEND_KDS_INTEGRATION.md` / earlier planning:

1. **No device approval workflow** — devices auto-register on first successful login; no pending/approve UI.
2. **No PIN lockout** — repeated wrong PINs do not lock the staff account; always `INVALID_PIN`.
3. **Device station is not a restriction** — `PUT /devices/me/station` is a saved default only; any allowed staff/device can view/act on any station by passing that `stationId`.
4. **`DEVICE_NOT_ALLOWED` is a kill-switch**, not “awaiting approval”.
5. **Roles** — login returns `["kds_operator"]` when KDS is allowed (not a richer role matrix).
6. **Item flags** — use `isNew` and `isRemoved`. Live active / WS payloads **include** removed lines with `isRemoved: true` (they do not silently vanish).
7. **Completing all items does not complete the order** — matches the original spec’s intent; restated here because it is easy to implement wrong. Explicit `POST .../complete` is required.
8. **Printer-based routing sync is gone** — stations/products come from bootstrap; routing is managed in MSIRms KDS Management (manual). Frontend only consumes bootstrap station/product lists.
9. **Cancelled orders** stay on the active board as `status: "cancelled"` via `order.updated`. The original integration-spec `order.removed` “erase from board” path is **not** used for cancellations (and is not emitted today).
10. **Staging URL** is `http://localhost:5088` / `ws://localhost:5088/...` from current config — production URL is separate and TBD.

---

## Quick checklist for Flutter

- [ ] Persist `deviceId`; send on login, as `X-Device-Id`, in action bodies, and on WS query.
- [ ] Send fresh `X-Request-Id` on every authenticated REST call.
- [ ] Login → bootstrap → station picker → `PUT /devices/me/station` → load orders → open WS.
- [ ] Treat `orderId` / `itemId` as opaque; never synthesize them.
- [ ] On every WS/`sync` order payload: **replace** local order by id.
- [ ] Render `status: "cancelled"` tickets as Cancelled (keep visible); do not listen for `order.removed`.
- [ ] Render `isRemoved: true` lines on the ticket (keep visible); highlight while `isRemovedUnseen: true` (same pattern as `isNew`).
- [ ] Acknowledge removed lines via `PATCH` with `acknowledgeRemoved: true` (not via complete toggle).
- [ ] Item toggles only while `cooking`; board complete requires explicit complete API.
- [ ] On `409 VERSION_CONFLICT`, adopt `order` from the error body, then retry if still appropriate.
- [ ] On reconnect: `client.hello` with `lastCursor`; if `syncRequired`, call `/sync` or full reload.
- [ ] Answer `ping` with `pong` using the same `messageId`.
- [ ] Do not build device-approval or PIN-lockout flows.
