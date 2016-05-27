require 'json'
require 'zlib'

list = Dir.glob("../raw/**/*.json.gz")

open('/tmp/heatmap.js', 'w') do |out|
  out.puts %|var x = {};|

  list.each.with_index do |file, idx|
    puts "#{idx/list.size.to_f*100.0}%" if idx % 1000 == 0

    j = JSON.parse(Zlib::GzipReader.open(file).read) rescue next
    ts = File.basename(file, '.json').to_i
    out.puts %|x[#{ts}] = [|

    j['marker'].each do |station|
      # id = station['hal2option']['standort_id']
      lat = station['lat'][0..8]
      lng = station['lng'][0..8]
      bikes = station['hal2option']['bikes'].count(',') + 1

      out.puts "[#{lat}, #{lng}, #{bikes}],"
    end

    out.puts "];"
  end
end

