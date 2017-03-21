require 'thor'
require 'pathname'
require 'memdump'

module MemDump
    class CLI < Thor
        desc 'enable-allocation-trace PID', 'enable the tracing of allocations on a running process'
        def enable_allocation_trace(pid)
            system('rbtrace', '-p', pid.to_s, '-e', "require \"objspace\"; ObjectSpace.trace_object_allocations_start")
        end

        desc 'dump PID FILE', 'generate a dump file from a running process'
        def dump(pid, file)
            file = File.expand_path(file)
            system('rbtrace', '-p', pid.to_s, '-e', "require \"objspace\"; File.open(\"#{file}\", 'w') { |io| ObjectSpace.dump_all(output: io) }")
        end

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
        def gml(dump_path, gml_path = nil)
            require 'memdump/convert_to_gml'

            STDOUT.sync = true
            dump_path = Pathname.new(dump_path)
            if gml_path
                gml_path = Pathname.new(gml_path)
            else
                gml_path = dump_path.sub_ext('.gml')
            end

            dump = MemDump::JSONDump.new(dump_path)
            gml_path.open('w') do |io|
                MemDump.convert_to_gml(dump, io)
            end
        end

        desc "subgraph_of DUMP ADDRESS", "traces all objects that are reachable from the given object"
        option :max_depth, desc: 'depth of the subgraph to generate', type: :numeric, default: Float::INFINITY
        def subgraph_of(dump, address)
            require 'memdump/subgraph_of'

            STDOUT.sync = true
            dump = MemDump::JSONDump.new(Pathname.new(dump))
            MemDump.subgraph_of(dump, address, max_depth: options[:max_depth]).each do |r|
                puts JSON.dump(r)
            end
        end

        desc "root_of DUMP ADDRESS", "traces the object with the given address to the root that's holding it alive"
        def root_of(dump, address)
            require 'memdump/root_of'

            STDOUT.sync = true
            dump = MemDump::JSONDump.new(Pathname.new(dump))
            MemDump.root_of(dump, address).each do |r|
                puts JSON.dump(r)
            end
        end

        desc 'replace-class DUMP OUTPUT', 'replaces the class address by the class name'
        option :add_ref, desc: 'whether a reference to the class object should be added', type: :boolean, default: false
        def replace_class(dump_path, output_path = nil)
            require 'memdump/replace_class_address_by_name'

            STDOUT.sync = true
            dump_path = Pathname.new(dump_path)
            output_path =
                if output_path then Pathname.new(output_path)
                else dump_path
                end
            dump = MemDump::JSONDump.new(dump_path)
            result = MemDump.replace_class_address_by_name(dump, add_reference_to_class: options[:add_ref])
            output_path.open('w') do |io|
                result.each do |r|
                    io.puts JSON.dump(r)
                end
            end
        end

        desc 'cleanup-refs DUMP OUTPUT', "removes references to deleted objects"
        def cleanup_refs(dump, output)
            require 'memdump/cleanup_references'

            STDOUT.sync = true
            dump = MemDump::JSONDump.new(Pathname.new(dump))
            cleaned = MemDump.cleanup_references(dump)
            Pathname.new(output).open('w') do |io|
                cleaned.each do |r|
                    io.puts JSON.dump(r)
                end
            end
        end

        desc 'remove-node DUMP NODE', 'remove all objects that are kept alive by the given node'
        def remove_node(dump, node_id)
            require 'memdump/remove_node'

            STDOUT.sync = true
            dump = MemDump::JSONDump.new(Pathname.new(dump))
            cleaned = MemDump.remove_node(dump, node_id)
            cleaned.each do |r|
                STDOUT.puts JSON.dump(r)
            end
        end

        desc 'stats DUMP', 'give statistics on the objects present in the dump'
        def stats(dump)
            require 'pp'
            require 'memdump/stats'
            dump = MemDump::JSONDump.new(Pathname.new(dump))
            unknown, by_type = MemDump.stats(dump)
            puts "#{unknown} objects without a known type"
            by_type.sort_by { |n, v| v }.reverse.each do |n, v|
                puts "#{n}: #{v}"
            end
        end

        desc 'out_degree DUMP', 'display the direct count of objects held by each object in the dump'
        option "min", desc: "hide the objects whose degree is lower than this",
            type: :numeric
        def out_degree(dump)
            dump = MemDump::JSONDump.new(Pathname.new(dump))
            min = options[:min] || 0
            sorted = dump.each_record.sort_by { |r| (r['references'] || Array.new).size }
            sorted.each do |r|
                size = (r['references'] || Array.new).size
                break if size > min
                puts "#{size} #{r}"
            end
        end

        desc 'interactive DUMP', 'loads a dump file and spawn a pry shell'
        option :load, desc: 'load the whole dump in memory', type: :boolean, default: true
        def interactive(dump)
            require 'memdump'
            require 'pry'
            dump = MemDump::JSONDump.new(Pathname.new(dump))
            if options[:load]
                dump = dump.load
            end
            dump.pry
        end
    end
end


