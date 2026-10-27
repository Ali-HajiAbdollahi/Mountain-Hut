set -e
cd "$(dirname "$0")"                                                                # current folder "database"
DB=mountain_hut.db                                                                  # db name 
rm -f "$DB" "$DB-wal" "$DB-shm"                                                     # removing the current db (if exists)
sqlite3 "$DB" < schema.sql                                                          # building db from schema.sql description
[ -f seed.sql ] && sqlite3 "$DB" "PRAGMA foreign_keys = ON;" ".read seed.sql"       # successively add seed (if exists) to db
echo "Database initialized: database/$DB"
