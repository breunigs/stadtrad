
Dir.glob("../raw/**/*.json.gz").each do |f|
  `zcat "#{f}" | perl -0777 -pe 's/"bikelist": \[.*?\],//igs' | gzip > "#{f}_small"`
end

puts "maybe run:"
puts "rm **/*.gz"
puts "rename 's/_small//' **/*_small"
