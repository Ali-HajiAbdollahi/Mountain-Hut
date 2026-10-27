# Mountain-Hut

#### License Motivations
---
We chose GPLv3 because we do not want our code to be reused in proprietary products. As a strong copyleft license, it requires anyone distributing a modified version to release the full source code under the same license. We did not extend this obligation to online services, which is why we preferred GPLv3 over AGPLv3. Our dependencies use permissive licenses (MIT, BSD, Apache 2.0) compatible with GPLv3.

#### Database
---
The SQLite schema is in [database/schema.sql](database/schema.sql). To (re)create the local database:

```sh
./database/init.sh   # creates database/mountain_hut.db (ignored by git)
```

If `database/seed.sql` exists, it is loaded after the schema; it contains sample data (development only). The application must run `PRAGMA foreign_keys = ON` on every connection.

#### Project structure
---
```
client/              frontend
server/
  dao/               database access 
  routes/            API endpoints
  services/          business logic 
database/            SQLite schema, seed and init script
```