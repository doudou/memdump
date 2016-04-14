module MemDump
    def self.root_of(dump, root_address)
        selected_records = Hash.new
        remaining_records = Array.new
        dump.each_record do |r|
            address = (r['address'] || r['root'])
            selected_records[address] = r
        end
        remaining_records << selected_records.delete(root_address)

        count = 0
        while count != selected_records.size
            count = selected_records.size
            remaining_records.delete_if do |r|
                references = r['references']
                if references && references.any? { |a| selected_records.has_key?(a) }
                    address = (r['address'] || r['root'])
                    selected_records[address] = r
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

