module MemDump
    def self.convert_to_gml(dump, io)
        io.puts "graph"
        io.puts "["

        edges = []
        dump.each_record do |row|
            address = row['address']

            io.puts "  node"
            io.puts "  ["
            io.puts "    id #{address}"
            row.each do |key, value|
                if value.respond_to?(:to_str)
                    io.puts "    #{key} \"#{value}\""
                elsif value.kind_of?(Numeric)
                    io.puts "    #{key} #{value}"
                end
            end
            io.puts "  ]"

            row['references'].each do |ref_address|
                edges << address << ref_address
            end
        end

        edges.each_slice(2) do |address, ref_address|
            io.puts "  edge"
            io.puts "  ["
            io.puts "    source #{address}"
            io.puts "    target #{ref_address}"
            io.puts "  ]"
        end

        io.puts "]"
    end
end
