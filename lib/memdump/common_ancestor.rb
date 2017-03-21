module MemDump
    def self.common_ancestors(dump, class_name, threshold: 0.1)
        selected_records  = Hash.new
        remaining_records = Array.new
        dump.each_record do |r|
            if class_name === r['class']
                selected_records[r['address']] = r
            else
                remaining_records << r
            end
        end

        remaining_records = Array.new
        selected_records = Hash.new
        selected_root = root_address
        dump.each_record do |r|
            address = (r['address'] || r['root'])
            if selected_root == address
                selected_records[address] = r
                selected_root = nil;
            else
                remaining_records << r
            end
        end

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

        selected_records.values.reverse.each do |r|
            if refs = r['references']
                refs.delete_if { |a| !selected_records.has_key?(a) }
            end
        end
    end
end
