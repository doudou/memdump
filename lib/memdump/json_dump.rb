require 'json'
module MemDump
    class JSONDump
        def initialize(filename)
            @filename = filename
        end

        def each_record
            return enum_for(__method__) if !block_given?

            if @cached_entries
                @cached_entries.each(&proc)
            else
                @filename.open do |f|
                    f.each_line do |line|
                        yield JSON.parse(line)
                    end
                end
            end
        end
    end
end

