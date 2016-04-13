require 'set'

module MemDump
    def self.convert_to_gml(dump, io)
        class_names = Hash.new
        dump.each_record do |row|
            if row['type'] == 'CLASS'
                class_names[row['address']] = row['name']
            end
        end

        squash = Hash[
            ['ARRAY', nil] => '[]',
            ['HASH', nil]  => '{}',
            ['NODE', nil]  => '->',
            ['STRING', nil]  => '',
            ['DATA', 'iseq'] => '->'
        ]

        prune = ['ROOT', 'ARRAY', 'HASH', 'NODE', 'STRING']

        io.puts "graph"
        io.puts "["
        squashed_nodes = Hash.new
        in_degree = Hash.new(0)
        nodes = dump.each_record.map do |row|
            next if row['type'] == 'ROOT'

            class_name = class_names[row['class']] || row['type']
            if row['name']
                class_name = "#{row['name']} - #{class_name}"
            end
            address = row['address']
            refs = (row['references'] || Array.new).uniq
            refs.each do |r|
                in_degree[r] += 1
            end

            if squashed_label = squash[[row['type'], row['struct']]]
                squashed_nodes[address] = [address, refs.uniq, class_name, squashed_label]
                next
            end
            [address, refs, class_name]
        end

        nodes.each do |address, refs, class_name|
            next if !address
            next if in_degree[address] == 0 && refs.empty?
            io.puts "  node"
            io.puts "  ["
            io.puts "    id #{address}"
            io.puts "    label \"#{class_name}\""
            io.puts "  ]"
        end

        nodes.each do |address, refs, _|
            next if !address

            stack = Set.new
            queue = refs.map { |target| [target, ""] }
            while !queue.empty?
                target, label = queue.shift

                _, squash_references, _, squash_label = squashed_nodes[target]
                if squash_references
                    if !squash_references.empty? && !stack.include?(target)
                        queue.concat(squash_references.map { |a| [a, label + squash_label] })
                    end
                    stack << target
                    next
                end

                io.puts "  edge"
                io.puts "  ["
                io.puts "    source #{address}"
                io.puts "    target #{target}"
                if !label.empty?
                    io.puts "    label \"#{label}\""
                end
                io.puts "  ]"
            end
        end
        io.puts "]"
    end
end
