require 'json'
require 'zlib'

list = Dir.glob("../raw/**/*.json.gz")
lsize = list.size

stats = {}
station_lookup = {}

list.each.with_index do |file, idx|
  puts "#{idx/lsize.to_f*100.0}%" if idx % 1000 == 0

  j = JSON.parse(Zlib::GzipReader.open(file).read) rescue next
  ts = File.basename(file, '.json').to_i
  hourly = Time.at(ts).strftime('%a-%H')

  stats[hourly] ||= {}

  j['marker'].each do |station|
    id = station['hal2option']['standort_id'].to_i

    station_lookup[id] ||= {
      lat: station['lat'][0..8],
      lng: station['lng'][0..8]
    }

    bikes = station['hal2option']['bikes'].count(',') + 1

    stats[hourly][id] ||= []
    stats[hourly][id] << bikes
  end
end


open('/tmp/heatmap_grouped.js', 'w') do |out|
  out.puts %|var x = {};|

  stats.each do |ts, list|
    out.puts %|x["#{ts}"] = [|
    list.each do |station_id, bike_counts|
      lat = station_lookup[station_id][:lat]
      lng = station_lookup[station_id][:lng]
      avg = bike_counts.inject(0, :+) / bike_counts.size.to_f
      out.puts "[#{lat}, #{lng}, #{avg}],"
    end
    out.puts "];"
  end
end
