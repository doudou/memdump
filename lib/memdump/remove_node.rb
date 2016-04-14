module MemDump
    def self.remove_node(dump, removed_node)
        remaining_records = Hash.new
        non_roots = Set.new
        dump.each_record do |r|
            address = (r['address'] || r['root'])
            remaining_records[address] = r

            if refs = r['references']
                refs.each do |ref_address|
                    non_roots << ref_address
                end
            end
        end

        roots = remaining_records.each_key.
            find_all { |a| !non_roots.include?(a) }

        queue = roots.dup
        selected_records = Hash.new
        while !queue.empty?
            address = queue.shift
            next if address == removed_node

            if record = remaining_records.delete(address)
                selected_records[address] = record
                if refs = record['references']
                    refs.each do |ref_address|
                        queue << ref_address
                    end
                end
            end
        end

        selected_records.values.reverse.map do |r|
            if refs = r['references']
                refs.delete_if { |a| !selected_records.has_key?(a) }
            end
            r
        end
    end
end

