require 'pathname'
require 'json'
module MemDump
    class JSONDump
        def self.load(filename)
            new(filename).load
        end

        def initialize(filename)
            @filename = Pathname(filename)
        end

        def each_record
            return enum_for(__method__) if !block_given?

            @filename.open do |f|
                f.each_line do |line|
                    r = JSON.parse(line)
                    r['address'] ||= r['root']
                    r['references'] ||= Set.new
                    yield r
                end
            end
        end

        def load
            address_to_record = Hash.new
            generations = Hash.new
            each_record do |r|
                if !(address = r['address'])
                    raise "no address in #{r}"
                end
                r = r.dup

                if generation = r['generation']
                    generations[address] = r['address'] = "#{address}:#{generation}"
                end
                r['references'] = r['references'].to_set
                address_to_record[r['address']] = r
            end

            if !generations.empty?
                address_to_record.each_value do |r|
                    if class_address = r['class']
                        r['class'] = generations.fetch(class_address, class_address)
                    end
                    if class_address = r['class_address']
                        r['class_address'] = generations.fetch(class_address, class_address)
                    end

                    refs = Set.new
                    r['references'].each do |ref_address|
                        refs << generations.fetch(ref_address, ref_address)
                    end
                    r['references'] = refs
                end
            end
            MemoryDump.new(address_to_record)
        end

        def inspect
            to_s
        end
    end
end

