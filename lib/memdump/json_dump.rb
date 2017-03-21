require 'json'
module MemDump
    class JSONDump
        def initialize(filename)
            @filename = filename
        end

        def each_record
            return enum_for(__method__) if !block_given?

            @filename.open do |f|
                f.each_line do |line|
                    r = JSON.parse(line)
                    r['address'] ||= r['root']
                    r['references'] ||= Array.new
                    yield r
                end
            end
        end

        def load
            address_to_record = Hash.new
            each_record do |r|
                if !r['address']
                    raise "no address in #{r}"
                end
                r = r.dup
                r['references'] = r['references'].to_set
                address_to_record[r['address']] = r
            end
            MemoryDump.new(address_to_record)
        end

        def inspect
            to_s
        end
    end
end

