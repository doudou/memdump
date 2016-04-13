require 'set'

module MemDump
    def self.diff(from, to)
        from_objects = Set.new
        from.each_record { |r| from_objects << (r['address'] || r['root']) }
        puts "#{from_objects.size} objects found in source dump"

        selected_records = Hash.new
        remaining_records = Array.new
        to.each_record do |r|
            address = (r['address'] || r['root'])
            if !from_objects.include?(address)
                selected_records[address] = r
            else
                remaining_records << r
            end
        end

        total = remaining_records.size + selected_records.size
        count = 0
        while selected_records.size != count
            count = selected_records.size
            puts "#{count}/#{total} records selected so far"
            remaining_records.delete_if do |r|
                address = (r['address'] || r['root'])
                references = r['references']

                if references && references.any? { |r| selected_records.has_key?(r) }
                    selected_records[address] = r
                end
            end
        end
        puts "#{count}/#{total} records selected"

        selected_records.each_value do |r|
            r['addresses'].delete_if { |a| !selected_records.has_key?(a) }
        end
        selected_records.each_value
    end
end
