require 'set'

module MemDump
    def self.convert_to_gml(dump, io)
        nodes = dump.each_record.map do |row|
            if row['class_address'] # transformed with replace_class_address_by_name
                name    = row['class']
            else
                name    = row['struct'] || row['root'] || row['type']
            end

            address = row['address'] || row['root']
            refs = Hash.new
            if row_refs = row['references']
                row_refs.each { |r| refs[r] = nil }
            end

            [address, refs, name]
        end

        io.puts "graph"
        io.puts "["
        known_addresses = Set.new
        nodes.each do |address, refs, name|
            known_addresses << address
            io.puts "  node"
            io.puts "  ["
            io.puts "    id #{address}"
            io.puts "    label \"#{name}\""
            io.puts "  ]"
        end

        nodes.each do |address, refs, _|
            refs.each do |ref_address, ref_label|
                io.puts "  edge"
                io.puts "  ["
                io.puts "    source #{address}"
                io.puts "    target #{ref_address}"
                if ref_label
                    io.puts "    label \"#{ref_label}\""
                end
                io.puts "  ]"
            end
        end
        io.puts "]"
    end
end
