module MemDump
    def self.cleanup_references(dump)
        addresses = Set.new
        records = Array.new
        dump.each_record do |r|
            addr = (r['address'] || r['root'])
            addresses << addr
            records << r
        end

        records.each do |r|
            if references = r['references']
                references.delete_if { |r| !addresses.include?(r) }
            end
        end
        records
    end
end

