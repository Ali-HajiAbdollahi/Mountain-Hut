# Mountain-Hut

## License Motivations

We chose GPLv3 because we do not want our code to be reused in proprietary products. As a strong copyleft license, it requires anyone distributing a modified version to release the full source code under the same license. We did not extend this obligation to online services, which is why we preferred GPLv3 over AGPLv3. Our dependencies use permissive licenses (MIT, BSD, Apache 2.0) compatible with GPLv3.

## Project Overview

Mountain-Hut is a web application for managing reservations and services at a mountain hut. It provides functionality for hikers and hut employees, including account management, reservation creation, modification and cancellation, availability checking, table allocation, staff-assisted bookings, weekly schedules, meal menus, and the registration and monitoring of planned hikes.

The application is composed of a Flutter web client and a Node.js backend. The backend exposes a REST API and uses SQLite for persistent data storage.

## Technologies

| Component          | Technology           |
| ------------------ | -------------------- |
| Frontend           | Flutter and Dart     |
| Backend            | Node.js and Express  |
| Database           | SQLite               |
| Backend testing    | Vitest and Supertest |
| Frontend testing   | Flutter Test         |
| API communication  | HTTP and JSON        |
| Session management | Express Session      |

The backend requires Node.js 24. The Flutter client requires a compatible Flutter SDK and Dart SDK 3.11.1 or later within the version range specified in `client/pubspec.yaml`.

## Requirements

Before installing the project, ensure that the following tools are available:

- Git
- Node.js 24 and npm
- Flutter SDK, including Dart
- SQLite support through the project's Node.js dependencies

The commands below assume that the repository has been cloned locally and that the terminal is positioned in the project root directory.

## Installation and Configuration

### 1. Backend installation

Move to the backend directory:

```bash
cd server
```

Install the dependencies:

```bash
npm ci
```

Create the local environment configuration file:

```bash
cp .env.example .env
```

Edit `server/.env` and configure the required environment variables:

```env
PORT=3001
CLIENT_ORIGIN=http://localhost:5173
SESSION_SECRET=replace-with-a-random-secret-at-least-32-characters

MAIL_MODE=disabled
SMTP_HOST=
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=
SMTP_PASS=
MAIL_FROM=
```

`SESSION_SECRET` must be replaced with a randomly generated secret containing at least 32 characters.

The application supports two email modes:

- `disabled`: email delivery is disabled.
- `smtp`: email delivery is performed through the configured SMTP server.

For local development, the default `disabled` mode is sufficient.

### 2. Database

The SQLite schema is in [database/schema.sql](database/schema.sql). To (re)create the local database:

```sh
./database/init.sh   # creates database/mountain_hut.db (ignored by git)
```

If `database/seed.sql` exists, it is loaded after the schema; it contains sample data (development only). The application must run `PRAGMA foreign_keys = ON` on every connection.

**Important:** the initialization script recreates the local database. It should only be used when a fresh database is required. Existing database contents should be backed up before running it.

### 3. Frontend installation

Open a separate terminal and move to the Flutter client directory:

```bash
cd client
```

Install the Flutter dependencies:

```bash
flutter pub get
```

## Running the Application

The backend and frontend must run simultaneously in separate terminals.

### Starting the backend

From the `server` directory, start the application with:

```bash
npm start
```

For development, the following command enables Node.js watch mode:

```bash
npm run dev
```

The backend listens on port `3001` by default. Its API base URL is:

```text
http://localhost:3001/api
```

### Starting the Flutter web client

From the `client` directory, run:

```bash
flutter run -d chrome \
  --web-hostname localhost \
  --web-port 5173 \
  --dart-define=API_BASE_URL=http://localhost:3001/api
```

The client is then available at:

```text
http://localhost:5173
```

The `API_BASE_URL` build-time variable specifies the backend API endpoint. The backend's `CLIENT_ORIGIN` configuration must correspond to the address used by the frontend.

## Running with Docker (Release 1)

The whole system (Node.js backend, Flutter web app and SQLite database) runs in a single container.

- Docker image: [`nicolecaldarazzo/mountain-hut:release1`](https://hub.docker.com/r/nicolecaldarazzo/mountain-hut)
- Source code: [github.com/Ali-HajiAbdollahi/Mountain-Hut](https://github.com/Ali-HajiAbdollahi/Mountain-Hut)

### 1. Requirements

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Windows, macOS) or Docker Engine (Linux), installed and running ("Engine running" in Docker Desktop).
- The file `secrets.env`, which contains the session secret (`SESSION_SECRET`).

### 2. Start the system

1. Extract `secrets.env` from `Team05-secrets.zip` into any folder.
2. Open a terminal **in that folder.**
3. Download and start the container:

```bash
docker pull nicolecaldarazzo/mountain-hut:release1
docker run --name mountain-hut -p 3001:3001 -p 8025:8025 --env-file secrets.env -v mountainhut-data:/data nicolecaldarazzo/mountain-hut:release1
```

4. Wait for `API listening on port 3001`, then open **http://localhost:3001** in the browser.
5. The emails sent by the system (booking confirmation, booking change, password reset) are collected by [Mailpit](https://mailpit.axllent.org/), included in the container: open **http://localhost:8025** to read them.

If `secrets.env` is in another folder, pass its full path: `--env-file C:\path\to\secrets.env`.

On the first start the database is created from `database/schema.sql` and `database/seed.sql`, with the test accounts listed in [Test Accounts and Sample Data](#test-accounts-and-sample-data) and three meal slots in the coming days: tomorrow lunch (12:00–13:00), tomorrow dinner (19:00–20:30) and lunch in three days. The data is kept in the Docker volume `mountainhut-data`.

To use two accounts at the same time (e.g. Elena and Marco), use a normal window and a private/incognito window: in the same browser window, a new sign-in replaces the previous one.

### 3. Stop, restart, reset

| Action                         | Command                                                                                                          |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------------- |
| Stop                           | `Ctrl+C` in the terminal, or `docker stop mountain-hut`                                                      |
| Start again (the data is kept) | `docker start -a mountain-hut`                                                                                 |
| Start from a clean database    | `docker rm -f mountain-hut`, then `docker volume rm mountainhut-data`, then the `docker run` command again |

### 4. Options

- **Another port:** if port 3001 is busy, use e.g. `-p 8080:3001 -e CLIENT_ORIGIN=http://localhost:8080` and open `http://localhost:8080`. `CLIENT_ORIGIN` must match the address in the browser, otherwise sign-in is refused ("Origin not allowed").
- **Emails:** by default the emails go to the Mailpit inbox inside the container (http://localhost:8025); they are not delivered to real mailboxes. To send real emails through another SMTP server, add to `secrets.env`: `START_MAILPIT=false`, `SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, `SMTP_USER`, `SMTP_PASS`, `MAIL_FROM`. To disable emails, add `MAIL_MODE=disabled`.

### 5. Building the image

From the repository root:

```bash
docker build -t nicolecaldarazzo/mountain-hut:release1 .
docker push nicolecaldarazzo/mountain-hut:release1
```

The `Dockerfile` compiles the Flutter web app (`flutter build web --release --dart-define=API_BASE_URL=/api`) and serves it from the Node.js backend on the same port. On the first start, `server/scripts/start-docker-server.js` creates the database in the `/data` volume. The `.dockerignore` file keeps `.env` files, local databases, `node_modules` and build caches out of the image.

## Testing

The project includes automated unit and integration tests for both the backend and the Flutter client, and end-to-end tests that run the client against the backend.

### Backend tests

All backend tests:

```bash
cd server
npm test
```

Unit tests only:

```bash
npm run test:unit
```

Integration tests only:

```bash
npm run test:integration
```

The backend test suite uses Vitest. Integration tests use Supertest to exercise HTTP endpoints.

Each integration test context creates a fresh SQLite database in memory using the project schema. Email delivery is replaced with a fake mail service, so tests do not require an external SMTP server.

The shared test fixtures use the following password:

```text
password123
```

This password is reserved for automated test fixtures and must not be considered a production credential.

### Flutter tests

All Flutter tests:

```bash
cd client
flutter test
```

The Flutter test suite is organized into unit and integration tests:

```bash
flutter test test/unit
flutter test test/integration
```

The unit tests verify individual client components and application logic. The integration tests cover the main application stories and their interactions with the client-side infrastructure.

### End-to-end tests

The end-to-end tests in `client/e2e_test/` run the real Flutter application against the real backend, one file per user story. Each test interacts with the application as a user would and then verifies the result through the API.

Two terminals are required.

Terminal 1, from the repository root, starts the backend on a fresh temporary database:

```bash
cd server
npm run start:e2e
```

This database is created from `database/schema.sql` and `database/seed.sql` at every start; the development database is not modified and email delivery is disabled. Port `3001` must be free, so the development backend must be stopped first. Stop the backend with `Ctrl+C` when the tests have finished.

Terminal 2, from the repository root, runs all the stories in Chrome:

```bash
cd client
bash e2e_test/run_e2e_chrome.sh
```

The script requires Chrome, Flutter and Node.js. It downloads the ChromeDriver version matching the installed Chrome into `client/.dart_tool/`, serves the application on port `5173` (the origin allowed by the backend) and runs the stories one after the other. The run ends with `All E2E files passed.` or with the list of the failing files.

Alternatively, the same tests can run on the Windows desktop application, which requires Windows Developer Mode and Visual Studio with the "Desktop development with C++" workload:

```bash
cd client
bash e2e_test/run_e2e.sh
```

On Windows, the `bash` commands must be run from Git Bash. From PowerShell, use `& "C:\Program Files\Git\bin\bash.exe" e2e_test/run_e2e_chrome.sh` instead.

If a Chrome run stops with `Timed out receiving message from renderer`, the browser failed to start: run the script again.

### Test coverage

Coverage is measured on the unit and integration tests together. The end-to-end tests run in the browser and are not included.

**Backend** (from the `server` folder):

```bash
cd server
npm ci
npm run coverage
```

The summary (statements, branches, functions, lines) is printed at the end, for the whole server code except the tests, the scripts and `index.js`. A detailed report, line by line, is written to `server/coverage/index.html`. To measure only one kind of test, add the folder: `npm run coverage -- tests/unit` or `npm run coverage -- tests/integration`.

**Frontend** (from the `client` folder):

```bash
cd client
flutter test --coverage
node -e "const t=require('fs').readFileSync('coverage/lcov.info','utf8');let f=0,h=0;for(const l of t.split('\n')){if(l.startsWith('LF:'))f+=+l.slice(3);if(l.startsWith('LH:'))h+=+l.slice(3)}console.log((100*h/f).toFixed(1)+'% ('+h+'/'+f+' lines)')"
```

`flutter test --coverage` writes `client/coverage/lcov.info`; the second command prints the line coverage (Flutter measures lines only). To measure only one kind of test, use `flutter test test/unit --coverage` or `flutter test test/integration --coverage`. The VS Code extension *Coverage Gutters* can show covered and uncovered lines from the same file.

Coverage reports are generated locally and are not committed (`coverage/` is ignored by git).

## Test Accounts and Sample Data

The development seed file, `database/seed.sql`, defines the following sample user profiles:

| Email             | Password        | Role     | Account status                                         |
| ----------------- | --------------- | -------- | ------------------------------------------------------ |
| `elena@hut.it`  | `password123` | Employee | Can sign in (Staff Portal)                             |
| `marco@mail.it` | `password123` | Hiker    | Can sign in                                            |
| `sara@mail.it`  | `password123` | Hiker    | Can sign in                                            |
| `luca@mail.it`  | —              | Hiker    | Profile created by an employee; no password configured |

The seed file stores only password hashes and salts; the login password of the sample accounts is `password123`. These accounts are available in the development database (`database/init.sh`), in the end-to-end backend (`npm run start:e2e`) and in the Docker container.

Luca's profile represents a hiker registered by an employee without an initial password. This profile cannot be used to log in until the account credentials are configured through the application's supported registration process.

These accounts and records are intended exclusively for development and demonstration purposes.

## Application Architecture

### Flutter Client

The frontend is organized by functional features, with shared application components grouped under `core`.

The `core` directory contains functionality used across multiple features:

- `constants`: application-wide constants.
- `errors`: exception and failure handling.
- `layout`: responsive application layout.
- `navigation`: application navigation components.
- `network`: HTTP client configuration, API endpoints, and backend communication.
- `theme`: colors, typography, and application theme.
- `utils`: shared utilities, including debouncing and validation.

The `features` directory separates the application into functional areas:

| Feature          | Responsibility                                                                 |
| ---------------- | ------------------------------------------------------------------------------ |
| `account`      | User account and profile pages                                                 |
| `auth`         | Registration, login, and authentication state                                  |
| `booking`      | Reservation creation and booking-related interfaces                            |
| `explore`      | Exploration and introductory application pages, meal times and menus           |
| `hike_registration` | Registration of a planned hike by a hiker                                 |
| `hiker_portal` | Hiker reservation overview and reservation management                          |
| `staff_portal` | Employee dashboard, slot management, weekly schedule copy, menus, hiker lookup, staff-assisted bookings, and active hikes |

Features that require data persistence or backend communication use separate data, domain, and presentation layers where applicable. This separation helps isolate user interface components from application logic and API communication.

### Node.js Backend

The backend follows a layered architecture that separates HTTP routing, business logic, and database access.

| Directory or file | Responsibility                                                       |
| ----------------- | -------------------------------------------------------------------- |
| `dao/`          | Data Access Objects responsible for database queries and persistence |
| `domain/`       | Domain-level logic, validation, time handling, and table allocation  |
| `middleware/`   | Request middleware, including authentication and error handling      |
| `routes/`       | REST API endpoint definitions                                        |
| `services/`     | Application and business logic                                       |
| `mail/`         | Email content: booking confirmation, booking change, password reset  |
| `tests/`        | Automated unit and integration tests                                 |
| `db.js`         | SQLite database initialization and connection management             |
| `app.js`        | Express application configuration                                    |
| `index.js`      | Backend application entry point                                      |
| `errors.js`     | Application error definitions                                        |

The backend is responsible for enforcing application rules, validating incoming requests, managing user sessions, coordinating reservation operations, and maintaining database consistency.

## Main Functionalities

The implemented functionality is organized around the following user stories.

**Sprint 1**

| ID    | User story                 | Main functionality                                                                                                                                                                                                                         |
| ----- | -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| MH-01 | Book a table               | Allows hikers to create reservations, subject to booking rules, available capacity, and table allocation constraints.                                                                                                                      |
| MH-02 | Define slot capacity       | Allows employees to define service time slots and configure the tables and seating capacity available for each slot. Slots start and end on the same day and cannot overlap; the table layout of another slot of the day can be reused. |
| MH-03 | Receive confirmation       | Provides booking confirmation notifications and handles email delivery outcomes.                                                                                                                                                           |
| MH-04 | Check availability         | Allows users to check available capacity for a selected date, time slot, and party size.                                                                                                                                                   |
| MH-05 | Specify party requirements | Allows hikers to provide dietary requirements, allergies, and additional information associated with a reservation, each for a subset of the party.                                                                                       |
| MH-06 | Change a booking           | Allows hikers to change the date, time, party size, or requirements of their reservations up to 48 hours before the meal. A party size change is treated as a new booking (tables assigned again), and every change is notified by email. |
| MH-07 | Reserve for an hiker       | Allows employees to reserve for existing, new, or temporary hikers until the slot starts. New full profiles get a random password that must be changed at the first sign-in; passwords can be recovered by email (link valid 24 hours).  |

**Sprint 2**

| ID    | User story               | Main functionality                                                                                                                                                                                       |
| ----- | ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| MH-08 | Cancel a booking         | Allows hikers to cancel their reservations at any time; the seats are released and offered to other guests.                                                                                              |
| MH-09 | Repeat a weekly schedule | Allows employees to copy all the slots and table layouts of a week into another week. A week that already has slots is completely replaced, after confirmation, unless it has reservations.             |
| MH-10 | Define menus             | Allows employees to write the menu of each slot as free text with basic formatting (bold, italic, font size, item lists and sub-items), and to reuse and change menus of previous slots and days.      |
| MH-20 | Register a hike          | Allows signed-in hikers to register a planned hike before departure: destination, route, intermediate passage points, departure time, and expected return time.                                          |
| MH-11 | View meal details        | Allows every user, without signing in, to see the meal times of a day and the formatted menu of each slot.                                                                                              |
| MH-21 | View active hikes        | Allows employees to see the hikers currently on a hike (departed and not yet returned), with destination, route, passage points, and expected return time; the list refreshes automatically.             |

Each user story is covered by backend unit and integration tests, corresponding Flutter unit and integration test files, and end-to-end tests (MH-20 and MH-21 share one end-to-end test file, `mh20_mh21_hike_monitoring_test.dart`).

## Database

The application uses SQLite as its relational database.

The database schema is defined in `database/schema.sql`, while `database/seed.sql` provides development sample data.

The main entities include:

- Users and their roles.
- Service time slots.
- Tables and their seating capacity.
- Reservations and their table allocations.
- Reservation requirements.
- Slot menus.
- Planned hikes and their intermediate passage points.
- Password reset tokens (only their hash is stored).

The database enforces relational constraints through primary keys, foreign keys, uniqueness constraints, and validation rules. Foreign-key enforcement must be enabled on every database connection.

## Project Structure

```text
Mountain-Hut/
├── client/                  Flutter frontend
│   ├── lib/
│   │   ├── core/            Shared application components
│   │   └── features/        Feature-based application modules
│   ├── test/
│   │   ├── unit/            Flutter unit tests
│   │   ├── integration/     Flutter integration tests
│   │   └── helpers/         Shared test utilities
│   ├── e2e_test/            End-to-end tests and run scripts
│   │   └── helpers/         Shared end-to-end test utilities
│   ├── test_driver/         Entry point used by flutter drive
│   └── pubspec.yaml
│
├── server/                  Node.js backend
│   ├── dao/                 Database access
│   ├── domain/              Domain logic and validation
│   ├── middleware/          Authentication and error handling
│   ├── routes/              REST API endpoints
│   ├── services/            Business logic
│   ├── mail/                Email-related components
│   ├── scripts/             Backend start-up for the end-to-end tests
│   ├── tests/
│   │   ├── unit/            Backend unit tests
│   │   ├── integration/     Backend integration tests
│   │   └── helpers/         Shared test utilities
│   ├── app.js
│   ├── db.js
│   ├── index.js
│   └── package.json
│
├── database/                SQLite schema, seed and initialization script
├── docs/                    API documentation
├── LICENSE.md
└── README.md
```
