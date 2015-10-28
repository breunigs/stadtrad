defmodule SqliteSetup do
  def create_tables do
    create_bike_history
    create_stats
  end

  defp create_bike_history do
    {:ok, db} = Sqlitex.open('bike_history.sqlite3')

    Sqlitex.query(db, "CREATE TABLE IF NOT EXISTS `history` (
      `station_id`  INTEGER NOT NULL,
      `bike_id` INTEGER NOT NULL,
      `timestamp` INTEGER NOT NULL
    )")
  end

  defp create_stats do
    {:ok, db} = Sqlitex.open('stats.sqlite3')

    Sqlitex.query(db, "CREATE TABLE IF NOT EXISTS `stations` (
      `name`  TEXT NOT NULL,
      `lat` NUMERIC,
      `lng` NUMERIC,
      `id`  INTEGER NOT NULL UNIQUE,
      PRIMARY KEY(id)
    )")

    Sqlitex.query(db, "CREATE TABLE IF NOT EXISTS `bike_count_history` (
      `station_id`  INTEGER NOT NULL,
      `timestamp` INTEGER NOT NULL,
      `bike_count`  INTEGER NOT NULL,
      FOREIGN KEY(`station_id`) REFERENCES stations ( id )
    )")
  end
end
