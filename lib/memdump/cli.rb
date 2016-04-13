require 'thor'
require 'pathname'
require 'memdump/json_dump'

module MemDump
    class CLI < Thor
        desc 'diff SOURCE TARGET OUTPUT', 'generate a memory dump that contains the objects in TARGET not in SOURCE, and all their parents'
        def diff(source, target, output)
            require 'memdump/diff'

            STDOUT.sync = true
            from = MemDump::JSONDump.new(Pathname.new(source))
            to   = MemDump::JSONDump.new(Pathname.new(target))
            records = MemDump.diff(from, to)
            File.open(output, 'w') do |io|
                records.each do |r|
                    io.puts JSON.dump(r)
                end
            end
        end

        desc 'gml DUMP GML', 'converts a memory dump into a graph in the GML format (for processing by e.g. gephi)'
        def gml(dump, gml)
            require 'memdump/convert_to_gml'

            STDOUT.sync = true
            dump = MemDump::JSONDump.new(Pathname.new(dump))
            io = File.open(gml, 'w') do |io|
                MemDump.convert_to_gml(dump, io)
            end
        end
    end
end


