defmodule StadtradStats do
  use Application

  def start(_,_) do
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
    Task.await b
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
      Sqlitex.Statement.bind_values(stmt_stations, [s.id, ts, length(s.bikes)])
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

    Enum.each(stations, fn(station) ->
      Enum.each(station.bikes, fn(bike_id) ->
        # update_station(station.id, bike_id, db, ts)
      end)
    end)
    IO.puts "✓ write bike history"
  end

  defp update_station(new_station_id, bike_id, db, ts) do
    [station_id: current_station_id] =
      Sqlitex.query(db,
        "SELECT station_id FROM history WHERE bike_id = ?1 ORDER BY timestamp DESC LIMIT 1",
        bind: [bike_id]
      ) |> hd
    #TODO: handle if no result


    if new_station_id != current_station_id do
      Sqlitex.query(db,
        "INSERT INTO history (station_id, bike_id, timestamp) VALUES (?1, ?2, ?3)",
        bind: [new_station_id, bike_id, ts]
      )
    end
  end

  @spec unix_time :: integer
  defp unix_time do
    {ms, s, _} = :os.timestamp
    ms * 1_000_000 + s
  end
end