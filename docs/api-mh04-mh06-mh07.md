# Mountain Hut Backend API: MH-04, MH-06 and MH-07

This document describes the backend API contracts for checking availability (MH-04), changing a booking (MH-06), and creating a reservation on behalf of a hiker (MH-07).

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

The backend's local `server/.env` should use the matching origin:

```dotenv
PORT=3001
CLIENT_ORIGIN=http://localhost:5173
```

The endpoint headings and raw HTTP examples below show the **full server path**, including `/api` (for example, `GET /api/availability`). When using the existing `MountainHutApi` client, use its endpoint constants or methods, which append suffixes such as `/availability` to the configured base URL. Do not append `/api` twice.

All request and response bodies use JSON unless stated otherwise. JSON body fields such as `tsID`, `n_people`, and `uID` must be numbers, not strings from text fields. Query parameters are URL strings; the client handles their encoding.

Times use the hut's local time in `Europe/Rome` and the format `YYYY-MM-DD HH:mm` where applicable. Slot timestamps have no UTC offset; display them as hut-local times rather than interpreting them as UTC.

The API uses a session cookie named `mh.sid`. The Flutter Web client should use `MountainHutApi` (which uses `BrowserClient()..withCredentials = true`) so the browser sends and receives the HTTP-only cookie. Do not try to read that cookie in application code. Log in through `POST /api/sessions` before calling endpoints that require a hiker or employee session. The role on the server-side session determines access; do not send a user ID or role to establish identity.

This documentation describes backend contracts. The current `MountainHutApi` supports MH-04 availability checks, but does not yet implement a `PATCH` method for MH-06 or staff-search/staff-booking methods for MH-07. Those client methods must be added before Flutter pages can call those endpoints through the shared client. The MH-07 backend router is now mounted at `/api/staff` by `app.js` and passed in from `index.js`.

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
| 400 | Invalid request data |
| 401 | Missing session or invalid authentication |
| 403 | Insufficient role or forbidden Origin |
| 404 | Resource does not exist or does not belong to the user |
| 409 | Conflict such as insufficient capacity, duplicate booking, or the MH-06 change window having expired |
| 413 | Request body too large |
| 503 | Database temporarily busy; the response may include `Retry-After: 1` |
| 500 | Internal server error |

The Flutter client converts HTTP errors into `ApiException` values containing `status`, `code`, and `message`. Use `status` and `code` to decide what the UI should do; `message` can be shown to the user where appropriate. A request timeout is represented as a client-side `ApiException` with `status: 0` and `code: TIMEOUT`, not as an HTTP response. Other network failures may throw other exceptions, so handle both.

Do not automatically retry a booking creation after a timeout or connection failure. The server may already have saved the booking. First retrieve the hiker's bookings or otherwise resolve the uncertain result.

For Flutter Web, create and share a `MountainHutApi` instance at an appropriate application scope; do not create it inside a widget's `build()` method. Call `api.close()` only when the owning component is disposed and the client is no longer needed. Native mobile and desktop targets need a suitable HTTP client and cookie-management strategy.

---

## MH-04 — Check availability

Checks a slot by its exact start date and time and returns the free-seat allocation for the requested party. Login is not required.

### `GET /api/availability`

Query parameters:

| Parameter | Required | Format | Meaning |
|---|---:|---|---|
| `date` | Yes | `YYYY-MM-DD` | Slot date |
| `time` | Yes | `HH:mm` | Exact slot start time, 24-hour clock |
| `partySize` | Yes | Positive integer | Number of hikers |

Example:

```http
GET /api/availability?date=2030-06-01&time=12:00&partySize=5
```

Available response (`200`):

```json
{
  "available": true,
  "partySize": 5,
  "slot": {
    "tsID": 12,
    "start_time": "2030-06-01 12:00",
    "end_time": "2030-06-01 13:00"
  },
  "allocation": [
    { "table_no": 1, "seats": 2 },
    { "table_no": 2, "seats": 3 }
  ]
}
```

When no slot starts at the requested date and time, the API returns `200` with `available: false`, `slot: null`, and an empty `allocation`. If a slot exists but does not have enough free seats, `slot` contains its details and `allocation` is empty. When possible, the API chooses a combination using the fewest tables; if multiple combinations use the same number of tables, it chooses the one with the least total free capacity. It then allocates the requested seats across those tables in order of increasing free capacity, using table number to break ties. The allocation reports seats reserved for this party, not each table's full capacity.

Invalid dates, times, or party sizes return `400`.

---

## MH-06 — Change a booking

A logged-in hiker can change a booking they own only if the meal starts at least 48 hours from the time of the change. Changes to party size or slot are subject to the availability check and automatic table allocation. When changing to a different timeslot, the target timeslot must also start at least two hours from the time of the change, following the MH-01 booking cutoff. Exactly 48 hours before the meal and exactly two hours before the target slot are allowed.

### `PATCH /api/bookings/:id`

Authentication: logged-in `hiker` who owns the booking.

The JSON body may include one or more of these fields. Unknown fields are rejected, and an empty body is rejected.

| Field | Type | Meaning |
|---|---|---|
| `tsID` | Positive integer | New timeslot ID |
| `n_people` | Positive integer | New party size |
| `requirements` | Array | Replacement list of dietary requirements/allergies |

Each requirement has this shape:

```json
{
  "n_people": 1,
  "description": "Peanut allergy",
  "allergy": true
}
```

- `n_people` is a positive integer or `null`. `null` means the requirement applies to the whole party. It cannot exceed the party size.
- `description` must be a non-empty string.
- `allergy` must be a boolean.
- Multiple requirements may overlap; their `n_people` values are not added together.
- If `requirements` is omitted, the existing requirements are kept. If it is supplied, it replaces the full existing list; use `[]` to clear the list.
- If `tsID` and `n_people` are both omitted, the table assignment is not recalculated.

Example:

```http
PATCH /api/bookings/42
Content-Type: application/json
```

```json
{
  "tsID": 15,
  "n_people": 4,
  "requirements": [
    { "n_people": 1, "description": "Peanut allergy", "allergy": true },
    { "n_people": null, "description": "No pork", "allergy": false }
  ]
}
```

Success response (`200`):

```json
{
  "booking": {
    "bID": 42,
    "tsID": 15,
    "uID": 2,
    "contact_name": "Marco Bianchi",
    "contact_phone": "3332220000",
    "n_people": 4,
    "start_time": "2030-06-03 12:00",
    "end_time": "2030-06-03 13:00",
    "reference": "MH-42",
    "tables": [
      { "table_no": 3, "seats": 4 }
    ],
    "requirements": [
      { "rID": 7, "n_people": 1, "description": "Peanut allergy", "allergy": true },
      { "rID": 8, "n_people": null, "description": "No pork", "allergy": false }
    ]
  }
}
```

The response also includes database fields such as `created_at` and `created_by` when present. A missing booking or a booking owned by another user returns `404`. A change made less than 48 hours before the meal, a move to a target timeslot starting less than two hours later, a duplicate booking in the target slot, or insufficient capacity returns `409`.

The current `MountainHutApi` does not support `PATCH` and has no `updateBooking()` method. Add the method to the client before wiring the edit-booking page; the path and JSON contract above describe the backend endpoint.

---

## MH-07 — Reserve for a hiker (employee API)

These endpoints let an employee search for a registered hiker and create a booking for an existing, temporary, or newly registered hiker. Authentication: logged-in `employee`.

> **Backend wiring:** `index.js` creates `staffBookingRouter` and passes it to `createApp`; `app.js` mounts it at `/api/staff` before the 404 handler. Once the server is running, these routes are available to authenticated employee sessions.

### Search registered hikers

#### `GET /api/staff/hikers?query={text}`

`query` must contain at least two characters. The search matches registered hikers by name, email, or phone (case-insensitive for name and email), and returns up to 20 results. Employee accounts are excluded.

Example:

```http
GET /api/staff/hikers?query=marco
```

Success response (`200`):

```json
{
  "hikers": [
    {
      "uID": 2,
      "name": "Marco Bianchi",
      "email": "marco@mail.it",
      "phone": "3332220000",
      "role": "hiker"
    }
  ]
}
```

### Create a booking for a hiker

#### `POST /api/staff/bookings`

The common top-level fields are:

| Field | Required | Type |
|---|---:|---|
| `hiker` | Yes | Object described below |
| `tsID` | Yes | Positive integer |
| `n_people` | Yes | Positive integer |
| `requirements` | No | Array; defaults to `[]` |

Choose exactly one hiker mode:

**Existing registered hiker** — use the `uID` returned by the search endpoint:

```json
{ "mode": "existing", "uID": 2 }
```

**Temporary hiker** — stores name and optional phone on the booking only; no user profile is created:

```json
{ "mode": "temporary", "name": "Walk-in guest", "phone": "3335550000" }
```

**Full registration** — creates a regular hiker account and the booking:

```json
{
  "mode": "register",
  "name": "New Hiker",
  "email": "new.hiker@example.com",
  "phone": "3335550000",
  "password": "choose-a-password"
}
```

The full-registration mode requires non-empty `name`, `email`, `phone`, and `password`; the regular registration service validates the email and requires a password of at least 8 characters. The temporary mode does not require an email or password.

Complete example:

```http
POST /api/staff/bookings
Content-Type: application/json
```

```json
{
  "hiker": { "mode": "existing", "uID": 2 },
  "tsID": 15,
  "n_people": 4,
  "requirements": [
    { "n_people": 1, "description": "Peanut allergy", "allergy": true },
    { "n_people": null, "description": "No pork", "allergy": false }
  ]
}
```

Success response (`201`):

```json
{
  "booking": {
    "bID": 43,
    "tsID": 15,
    "uID": 2,
    "contact_name": "Marco Bianchi",
    "contact_phone": "3332220000",
    "n_people": 4,
    "created_by": 1,
    "reference": "MH-43",
    "tables": [
      { "table_no": 3, "seats": 4 }
    ],
    "requirements": [
      { "rID": 9, "n_people": 1, "description": "Peanut allergy", "allergy": true },
      { "rID": 10, "n_people": null, "description": "No pork", "allergy": false }
    ]
  }
}
```

The actual response includes the booking's slot dates and saved requirements. It also includes a `Location` header with `/api/bookings/{bID}`. Temporary bookings have `uID: null`; registered hiker bookings have the profile's `uID`. `created_by` identifies the employee.

Invalid mode or input returns `400`; a missing slot or hiker returns `404`; duplicate booking or insufficient capacity returns `409`; and a missing login or non-employee login returns `401` or `403`, respectively.

The current Flutter API client does not yet define methods for either staff endpoint. Add them to the shared client before calling them from the employee reservation flow.

---

## Frontend integration checklist

1. For Flutter Web, use `API_BASE_URL=http://localhost:3001/api`; endpoint paths in this document show the full `/api/...` route, while the client methods append only the suffix after `/api`.
2. Use `GET /api/availability` for the public availability check; it does not create or hold a reservation.
3. Use `PATCH /api/bookings/{bID}` for a hiker changing their own reservation; send only the changed fields.
4. Use the `/api/staff` endpoints with an authenticated employee session; add corresponding Flutter client methods before wiring them to the employee reservation flow.
5. Display `error.message` to the user where suitable, and handle `409` as a booking conflict that may require selecting another slot or party size.
