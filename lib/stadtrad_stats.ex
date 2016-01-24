defmodule StadtradStats do
  use Application

  def start(_,_) do
    SqliteSetup.create_tables
    retrieve
    Supervisor.start_link [], strategy: :one_for_one
  end

  @url 'https://stadtrad.hamburg.de/kundenbuchung/hal2ajax_process.php'
  @params 'mapstadt_id=75&verwaltungfirma=&centerLng=9.986872299999959&centerLat=53.56661530000001&searchmode=default&with_staedte=N&buchungsanfrage=N&bereich=2&ajxmod=hal2map&callee=getMarker&requester=index&webfirma_id=510'
  defp retrieve do
    IO.puts "reading JSON…"

    case :httpc.request(:post, {@url, [], 'application/x-www-form-urlencoded', @params}, [], []) do
      { :error, reason } -> exit reason

      { :ok, { {_, status_code, _}, _, body} } -> (
        if status_code != 200, do: exit("Status Code not 200: #{status_code}")

        ts = unix_time

        IO.puts "writing…"
        a = Task.async fn -> write_sqlite(body, ts) end
        b = Task.async fn -> write_raw(body, ts) end
        Task.await a
        Task.await b
      )
    end
  end

  defp write_raw(data, ts) do
    File.mkdir_p "raw"
    {:ok, file} = File.open "raw/#{ts}.json.gz", [:write, :compressed]
    IO.binwrite file, data
    File.close file
    IO.puts "✓ write raw"
  end

  defp write_sqlite(json, ts) do
    stations = JsonReader.stations(json)

    a = Task.async fn -> write_basic_stats(stations, ts) end
    b = Task.async fn -> write_bike_history(stations, ts) end
    Task.await a
    Task.await b, 30*1000
  end

  defp write_basic_stats(stations, ts) do
    {:ok, db} = Sqlitex.open('stats.sqlite3')
    :ok = Sqlitex.exec(db, "BEGIN TRANSACTION")

    {:ok, stmt_stations} = Sqlitex.Statement.prepare(db, "INSERT OR IGNORE INTO stations (id, name, lat, lng) VALUES (?1, ?2, ?3, ?4)")
    Enum.each(stations, fn(s) ->
      Sqlitex.Statement.bind_values(stmt_stations, [s.id, s.name, s.lat, s.lng])
      Sqlitex.Statement.exec(stmt_stations)
    end)

    {:ok, stmt_bike_history} = Sqlitex.Statement.prepare(db, "INSERT INTO bike_count_history (station_id, timestamp, bike_count) VALUES (?1, ?2, ?3)")
    Enum.each(stations, fn(s) ->
      Sqlitex.Statement.bind_values(stmt_bike_history, [s.id, ts, length(s.bikes)])
      Sqlitex.Statement.exec(stmt_bike_history)
    end)

    :ok = Sqlitex.exec(db, "COMMIT TRANSACTION")
    IO.puts "✓ write basic stats"
  end

  defp write_bike_history(stations, ts) do
    {:ok, db} = Sqlitex.open('bike_history.sqlite3')

    current_positions = Sqlitex.query(db, "
      SELECT a.station_id, a.bike_id
      FROM history a LEFT JOIN history b
      ON a.bike_id = b.bike_id AND a.timestamp < b.timestamp
      WHERE b.timestamp IS NULL")

    lookup = Enum.into(current_positions,
      HashDict.new,
      fn x -> {x[:bike_id], x[:station_id]} end
    )

    :ok = Sqlitex.exec(db, "BEGIN TRANSACTION")

    {:ok, stmt} = Sqlitex.Statement.prepare(db, "INSERT INTO history (station_id, bike_id, timestamp) VALUES (?1, ?2, ?3)")

    Enum.each(stations, fn(station) ->
      Enum.each(station.bikes, fn(bike_id) ->
        if lookup[bike_id] != station.id do
          Sqlitex.Statement.bind_values(stmt, [station.id, bike_id, ts])
          Sqlitex.Statement.exec(stmt)
        end
      end)
    end)

    :ok = Sqlitex.exec(db, "COMMIT TRANSACTION")

    IO.puts "✓ write bike history"
  end

  @spec unix_time :: integer
  defp unix_time do
    {ms, s, _} = :os.timestamp
    ms * 1_000_000 + s
  end
end
