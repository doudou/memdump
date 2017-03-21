module MemDump
    def self.out_degree(dump)
        records = dump.each_record.sort_by { |r| (r['references'] || Array.new).size }
    end
end


