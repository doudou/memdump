module MemDump
    def self.subgraph_of(dump, root_address, max_depth: Float::INFINITY)
        remaining_records = Hash.new
        dump.each_record do |r|
            address = (r['address'] || r['root'])
            remaining_records[address] = r
        end

        selected_records = Hash.new
        queue = [[root_address, 0]]
        while !queue.empty?
            address, depth = queue.shift
            if record = remaining_records.delete(address)
                selected_records[address] = record
                if (depth < max_depth) && (refs = record['references'])
                    refs.each do |ref_address|
                        queue << [ref_address, depth + 1]
                    end
                end
            end
        end

        selected_records.values
    end
end

