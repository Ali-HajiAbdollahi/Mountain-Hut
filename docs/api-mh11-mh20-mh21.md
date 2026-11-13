# Mountain Hut Backend API: MH-11, MH-20 and MH-21

This document describes the backend API contracts for viewing meal details (MH-11), registering a planned hike (MH-20), and viewing active hikes as an employee (MH-21).

## Configuration and conventions

The Flutter client's API base URL includes `/api`:

```text
http://localhost:3001/api
```

It can be overridden at build time with `API_BASE_URL`:

```bash
flutter run -d chrome \
  --web-hostname localhost \
  --web-port 5173 \
  --dart-define=API_BASE_URL=http://localhost:3001/api
```

The endpoint headings and raw HTTP examples below show the full server path, including `/api`. When using the existing `MountainHutApi` client, use its endpoint constants or methods, which append paths to the configured base URL. Do not append `/api` twice.

All request and response bodies use JSON unless stated otherwise. JSON identifiers are numbers, not strings. Query parameters are URL strings and should be URL-encoded by the client.

Times use the hut's local time in `Europe/Rome` and the format `YYYY-MM-DD HH:mm`. Timestamps have no UTC offset; treat them as hut-local times.

The API uses a session cookie named `mh.sid`. Log in through `POST /api/sessions` before calling endpoints that require a hiker or employee session. The server-side session determines the user ID and role; do not send a user ID or role to establish identity.

The current `MountainHutApi` provides `listSlots()` and `getSlot()` for MH-11. It does not yet provide methods for hike registration or the active-hike list; add those client methods before wiring the MH-20 and MH-21 screens.

### Error response format

Errors use this JSON shape:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "A human-readable explanation"
  }
}
```

| HTTP status | Meaning |
|---|---|
| 400 | Invalid request data or path identifier |
| 401 | Missing session or invalid authentication |
| 403 | The logged-in user does not have the required role, or the Origin is forbidden |
| 404 | The requested timeslot does not exist |
| 409 | Database constraint conflict |
| 413 | Request body too large |
| 503 | Database temporarily busy; the response may include `Retry-After: 1` |
| 500 | Internal server error |

---

## MH-11 — View meal details

Meal times and menu text are available publicly. Login is not required. A slot without a published menu is returned with `menu: null`; a date with no slots returns an empty array.

### `GET /api/timeslots?date=YYYY-MM-DD`

Returns all slots starting on the requested date, ordered by start time. Existing slot fields are preserved, and each slot includes its menu.

Example:

```http
GET /api/timeslots?date=2026-12-01
```

Success response (`200`):

```json
[
  {
    "tsID": 12,
    "start_time": "2026-12-01 12:00",
    "end_time": "2026-12-01 13:00",
    "capacity": 14,
    "free_seats": 10,
    "tables": [
      { "table_no": 1, "seats": 2, "free_seats": 2 },
      { "table_no": 2, "seats": 4, "free_seats": 3 }
    ],
    "menu": "Polenta with mushrooms\nApple tart"
  },
  {
    "tsID": 13,
    "start_time": "2026-12-01 19:00",
    "end_time": "2026-12-01 20:30",
    "capacity": 16,
    "free_seats": 16,
    "tables": [
      { "table_no": 1, "seats": 8, "free_seats": 8 },
      { "table_no": 2, "seats": 8, "free_seats": 8 }
    ],
    "menu": null
  }
]
```

The `menu` value is text associated with that specific slot. Lunch and dinner on the same date can therefore have different menus. An unpublished menu is `null`; a date with no slots returns `200` and `[]`. A missing or invalid `date` returns `400`.

### `GET /api/timeslots/:id`

Returns one slot with its existing details and `menu` field. This endpoint is public. A positive integer ID is required; an invalid ID returns `400`, and an unknown slot returns `404`.

Example:

```http
GET /api/timeslots/12
```

The response has the same slot detail shape as an item in the daily list. `menu` is menu text or `null` if no menu has been published.

---

## MH-20 — Register a hike

A logged-in hiker can register a planned hike before departure. The owner ID is taken from the session and must not be sent in the request body. Intermediate waypoints are optional and are stored in the order supplied.

### `POST /api/hikes`

Authentication: logged-in `hiker`.

| Field | Required | Type | Meaning |
|---|---:|---|---|
| `destination` | Yes | String | Hike destination |
| `route` | Yes | String | Route description |
| `departure_time` | Yes | String | Planned departure in `YYYY-MM-DD HH:mm` format |
| `expected_return` | Yes | String | Expected return in `YYYY-MM-DD HH:mm` format |
| `waypoints` | No | Array of objects | Ordered intermediate points; defaults to `[]` |

Each waypoint has this shape:

```json
{ "name": "Vizo Mozzo" }
```

The destination, route, and waypoint names must be non-empty strings. Departure must not be in the past, and `expected_return` must be later than `departure_time`. A return on the following day is allowed. Unknown fields, including `uID`, are rejected.

Example:

```http
POST /api/hikes
Content-Type: application/json
```

```json
{
  "destination": "Chiaretto Lake",
  "route": "Via the east ridge",
  "departure_time": "2026-12-02 08:00",
  "expected_return": "2026-12-02 17:30",
  "waypoints": [
    { "name": "Vizo Mozzo" },
    { "name": "Old Bridge" }
  ]
}
```

Success response (`201`):

```json
{
  "hike": {
    "hID": 1,
    "uID": 2,
    "destination": "Chiaretto Lake",
    "route": "Via the east ridge",
    "departure_time": "2026-12-02 08:00",
    "expected_return": "2026-12-02 17:30",
    "returned_at": null,
    "created_at": "2026-12-01 10:15:00",
    "waypoints": [
      { "position": 1, "name": "Vizo Mozzo" },
      { "position": 2, "name": "Old Bridge" }
    ]
  }
}
```

The hike and its waypoints are saved in one database transaction. A failed waypoint insert rolls back the hike record as well. Invalid data returns `400`; an anonymous request returns `401`; a logged-in non-hiker receives `403`.

---

## MH-21 — View active hikes

An employee can see registered hikes that have started and have no recorded return. A hike remains in this list after its expected return time until a return is recorded. Future departures and hikes with `returned_at` set are excluded.

### `GET /api/hikes/active`

Authentication: logged-in `employee`.

The response is an array of hike summaries ordered by expected return time. Each hike is returned as a separate item, including when multiple hikers share a destination.

Example:

```http
GET /api/hikes/active
```

Success response (`200`):

```json
[
  {
    "hID": 1,
    "hiker_name": "Marco Bianchi",
    "destination": "Chiaretto Lake",
    "route": "Via the east ridge",
    "expected_return": "2026-12-02 17:30",
    "waypoints": [
      { "position": 1, "name": "Vizo Mozzo" },
      { "position": 2, "name": "Old Bridge" }
    ]
  }
]
```

If there are no active hikes, the API returns `200` and `[]`. An anonymous request returns `401`; a logged-in hiker receives `403`.

---

## Frontend integration checklist

1. Configure the API base URL as `http://localhost:3001/api`; the full endpoint paths in this document already include `/api`.
2. Use `GET /api/timeslots?date=YYYY-MM-DD` or `GET /api/timeslots/{tsID}` to read meal details and menus without login.
3. Use `POST /api/hikes` after a hiker has logged in; do not send `uID` in the body.
4. Use `GET /api/hikes/active` with an employee session. Treat the response as a JSON array and handle `[]` as an empty active-hike list.
5. Handle `401` as a missing/expired login, `403` as an incorrect role, and `400` as invalid request data.
