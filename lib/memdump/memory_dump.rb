module MemDump
    class MemoryDump
        attr_reader :address_to_record

        def initialize(address_to_record)
            @address_to_record = address_to_record
            @forward_graph = nil
            @backward_graph = nil
        end

        def include?(address)
            address_to_record.has_key?(address)
        end

        def each_record(&block)
            address_to_record.each_value(&block)
        end

        def addresses
            address_to_record.keys
        end

        def size
            address_to_record.size
        end

        def find_by_address(address)
            address_to_record[address]
        end

        def inspect
            to_s
        end

        def save(io_or_path)
            if io_or_path.respond_to?(:open)
                io_or_path.open 'w' do |io|
                    save(io)
                end
            else
                each_record do |r|
                    io_or_path.puts JSON.dump(r)
                end
            end
        end

        # Filter the records
        #
        # @yieldparam record a record
        # @yieldreturn [Object] the record object that should be included in the
        #   returned dump
        # @return [MemoryDump]
        def find_all
            return enum_for(__method__) if !block_given?

            address_to_record = Hash.new
            each_record do |r|
                if yield(r)
                    address_to_record[r['address']] = r
                end
            end
            MemoryDump.new(address_to_record)
        end
        
        # Map the records
        #
        # @yieldparam record a record
        # @yieldreturn [Object] the record object that should be included in the
        #   returned dump
        # @return [MemoryDump]
        def map
            return enum_for(__method__) if !block_given?

            address_to_record = Hash.new
            each_record do |r|
                address_to_record[r['address']] = yield(r.dup).to_hash
            end
            MemoryDump.new(address_to_record)
        end

        # Filter the entries, removing those for which the block returns falsy
        #
        # @yieldparam record a record
        # @yieldreturn [nil,Object] either a record object, or falsy to remove
        #   this record in the returned dump
        # @return [MemoryDump]
        def find_and_map
            return enum_for(__method__) if !block_given?

            address_to_record = Hash.new
            each_record do |r|
                if result = yield(r.dup)
                    address_to_record[r['address']] = result.to_hash
                end
            end
            MemoryDump.new(address_to_record)
        end

        # Return the records of a given type
        #
        # @param [String] name the type
        # @return [MemoryDump] the matching records
        #
        # @example return all ICLASS (singleton) records
        #   objects_of_class("ICLASS")
        def objects_of_type(name)
            find_all { |r| name === r['type'] }
        end

        # Return the records of a given class
        #
        # @param [String] name the class
        # @return [MemoryDump] the matching entries
        #
        # @example return all string records
        #   objects_of_class("String")
        def objects_of_class(name)
            find_all { |r| name === r['class'] }
        end

        # Return the entries that refer to the entries in the dump
        #
        # @param [MemoryDump] the set of entries whose parents we're looking for
        # @param [Integer] min only return the entries in self that refer to
        #   more than this much entries in 'dump'
        # @param [Boolean] exclude_dump exclude the entries that are already in
        #   'dump'
        # @return [(MemoryDump,Hash)] the parent entries, and a mapping from
        #   records in the parent entries to the count of entries in 'dump' they
        #   refer to
        def parents_of(dump, min: 0, exclude_dump: false)
            children = dump.addresses.to_set
            counts = Hash.new
            filtered = find_all do |r|
                next if exclude_dump && children.include?(r['address'])

                count = r['references'].count { |r| children.include?(r) }
                if count > min
                    counts[r] = count
                    true
                end
            end
            return filtered, counts
        end

        # Remove entries from this dump, keeping the transitivity in the
        # remaining graph
        #
        # @param [MemoryDump] entries entries to remove
        #
        # @example remove all entries that are of type HASH
        #    collapse(objects_of_type('HASH'))
        def collapse(entries)
            collapsed_entries = Hash.new
            entries.each_record do |r|
                collapsed_entries[r['address']] = r['references'].dup
            end


            # Remove references in-between the entries to collapse
            already_expanded = Hash.new { |h, k| h[k] = Set[k] }
            begin
                changed_entries  = Hash.new
                collapsed_entries.each do |address, references|
                    sets = references.classify { |ref_address| collapsed_entries.has_key?(ref_address) }
                    updated_references = sets[false] || Set.new
                    if to_collapse = sets[true]
                        to_collapse.each do |ref_address|
                            next if already_expanded[address].include?(ref_address)
                            updated_references.merge(collapsed_entries[ref_address])
                        end
                        already_expanded[address].merge(to_collapse)
                        changed_entries[address] = updated_references
                    end
                end
                puts "#{changed_entries.size} changed entries"
                collapsed_entries.merge!(changed_entries)
            end while !changed_entries.empty?

            find_and_map do |record|
                next if collapsed_entries.has_key?(record['address'])

                sets = record['references'].classify do |ref_address|
                    collapsed_entries.has_key?(ref_address)
                end
                updated_references = sets[false] || Set.new
                if to_collapse = sets[true]
                    to_collapse.each do |ref_address|
                        updated_references.merge(collapsed_entries[ref_address])
                    end
                    record = record.dup
                    record['references'] = updated_references
                end
                record
            end
        end

        # Remove entries from the dump, and all references to them
        #
        # @param [MemoryDump] the set of entries to remove, as e.g. returned by
        #   {#objects_of_class}
        # @return [MemoryDump] the filtered dump
        def without(entries)
            find_and_map do |record|
                next if entries.include?(record['address'])
                record_refs = record['references']
                references = record_refs.find_all { |r| !entries.include?(r) }
                if references.size != record_refs.size
                    record = record.dup
                    record['references'] = references.to_set
                end
                record
            end
        end

        # Write the dump to a GML file that can loaded by Gephi
        #
        # @param [Pathname,String,IO] the path or the IO stream into which we should
        #   dump
        def to_gml(io_or_path)
            if io_or_path.kind_of?(IO)
                MemDump.convert_to_gml(self, io_or_path)
            else
                Pathname(io_or_path).open 'w' do |io|
                    to_gml(io)
                end
            end
            nil
        end

        # Save the dump
        def save(io_or_path)
            if io_or_path.kind_of?(IO)
                each_record do |r|
                    r = r.dup
                    r['address'] = r['address'].gsub(/:\d+$/, '')
                    if r['class_address']
                        r['class_address'] = r['class_address'].gsub(/:\d+$/, '')
                    elsif r['address']
                        r['address'] = r['address'].gsub(/:\d+$/, '')
                    end
                    r['references'] = r['references'].map { |ref_addr| ref_addr.gsub(/:\d+$/, '') }
                    io_or_path.puts JSON.dump(r)
                end
                nil
            else
                Pathname(io_or_path).open 'w' do |io|
                    save(io)
                end
            end
        end

        COMMON_COLLAPSE_TYPES = %w{IMEMO HASH ARRAY}
        COMMON_COLLAPSE_CLASSES = %w{Set RubyVM::Env}

        # Perform common initial cleanup
        #
        # It basically removes common classes that usually make a dump analysis
        # more complicated without providing more information
        #
        # Namely, it collapses internal Ruby node types ROOT and IMEMO, as well
        # as common collection classes {COMMON_COLLAPSE_CLASSES}.
        #
        # One usually analyses a cleaned-up dump before getting into the full
        # dump
        #
        # @return [MemDump] the filtered dump
        def common_cleanup
            to_collapse = find_all do |r|
                COMMON_COLLAPSE_CLASSES.include?(r['class']) ||
                    COMMON_COLLAPSE_TYPES.include?(r['type'])
            end
            collapse(to_collapse)
        end

        # Remove entries in the reference for which we can't find an object with
        # the matching address
        #
        # @return [(MemoryDump,Set)] the filtered dump and the set of missing addresses found
        def remove_invalid_references
            addresses = self.addresses.to_set
            missing = Set.new
            result = map do |r|
                common = (addresses & r['references'])
                if common.size != r['references'].size
                    missing.merge(r['references'] - common)
                end
                r = r.dup
                r['references'] = common
                r
            end
            return result, missing
        end

        # Return the graph of object that keeps objects in dump alive
        #
        # It contains only the shortest paths from the roots to the objects in
        # dump
        #
        # @param [MemoryDump] dump
        # @return [MemoryDump]
        def roots_of(dump, root_dump: nil)
            if root_dump && root_dump.empty?
                raise ArgumentError, "no roots provided"
            end

            root_addresses =
                if root_dump then root_dump.addresses
                else
                    ['ALL_ROOTS']
                end

            ensure_graphs_computed

            result_nodes = Set.new
            dump_addresses = dump.addresses
            root_addresses.each do |root_address|
                visitor = RGL::DijkstraVisitor.new(@forward_graph)
                dijkstra = RGL::DijkstraAlgorithm.new(@forward_graph, Hash.new(1), visitor)
                dijkstra.find_shortest_paths(root_address)
                path_builder = RGL::PathBuilder.new(root_address, visitor.parents_map)

                dump_addresses.each_with_index do |record_address, record_i|
                    if path = path_builder.path(record_address)
                        result_nodes.merge(path)
                    end
                end
            end

            find_and_map do |record|
                address = record['address']
                next if !result_nodes.include?(address)

                # Prefer records in 'dump' to allow for annotations in the
                # source
                record = dump.find_by_address(address) || record
                record = record.dup
                record['references'] = result_nodes & record['references']
                record
            end
        end

        def minimum_spanning_tree(root_dump)
            if root_dump.size != 1
                raise ArgumentError, "there should be exactly one root"
            end
            root_address, _ = root_dump.address_to_record.first
            if !(root = address_to_record[root_address])
                raise ArgumentError, "no record with address #{root_address} in self"
            end

            ensure_graphs_computed

            mst = @forward_graph.minimum_spanning_tree(root)
            map = Hash.new
            mst.each_vertex do |record|
                record = record.dup
                record['references'] = record['references'].dup
                record['references'].delete_if { |ref_address| !mst.has_vertex?(ref_address) }
            end
            MemoryDump.new(map)
        end

        # @api private
        #
        # Ensure that @forward_graph and @backward_graph are computed
        def ensure_graphs_computed
            if !@forward_graph
                @forward_graph, @backward_graph = compute_graphs
            end
        end

        # @api private
        #
        # Force recomputation of the graph representation of the dump the next
        # time it is needed
        def clear_graph
            @forward_graph = nil
            @backward_graph = nil
        end

        # @api private
        #
        # Create two RGL::DirectedAdjacencyGraph, for the forward and backward edges of the graph
        def compute_graphs
            forward_graph  = RGL::DirectedAdjacencyGraph.new
            forward_graph.add_vertex 'ALL_ROOTS'
            address_to_record.each do |address, record|
                forward_graph.add_vertex(address)

                if record['type'] == 'ROOT'
                    forward_graph.add_edge('ALL_ROOTS', address)
                end
                record['references'].each do |ref_address|
                    forward_graph.add_edge(address, ref_address)
                end
            end

            backward_graph  = RGL::DirectedAdjacencyGraph.new
            forward_graph.each_edge do |u, v|
                backward_graph.add_edge(v, u)
            end
            return forward_graph, backward_graph
        end

        def depth_first_visit(root, &block)
            ensure_graphs_computed
            @forward_graph.depth_first_visit(root, &block)
        end

        # Validate that all reference entries have a matching dump entry
        #
        # @raise [RuntimeError] if references have been found
        def validate_references
            addresses = self.addresses.to_set
            each_record do |r|
                common = addresses & r['references']
                if common.size != r['references'].size
                    missing = r['references'] - common
                    raise "#{r} references #{missing.to_a.sort.join(", ")} which do not exist"
                end
            end
            nil
        end

        # Get a random sample of the records
        #
        # The sampling is random, so the returned set might be bigger or smaller
        # than expected. Do not use on small sets.
        #
        # @param [Float] the ratio of selected samples vs. total samples (0.1
        #   will select approximately 10% of the samples)
        def sample(ratio)
            result = Hash.new
            each_record do |record|
                if rand <= ratio
                    result[record['address']] = record
                end
            end
            MemoryDump.new(result)
        end

        # @api private
        #
        # Return the set of record addresses that are the addresses of roots in
        # the live graph
        #
        # @return [Set<String>]
        def root_addresses
            roots = self.addresses.to_set.dup
            each_record do |r|
                roots.subtract(r['references'])
            end
            roots
        end

        # Returns the set of roots
        def roots(with_keepalive_count: false)
            result = Hash.new
            self.root_addresses.each do |addr|
                record = find_by_address(addr)
                if with_keepalive_count
                    record = record.dup
                    count = 0
                    depth_first_visit(addr) { count += 1 }
                    record['keepalive_count'] = count
                end
                result[addr] = record
            end
            MemoryDump.new(result)
        end

        def add_children(roots, with_keepalive_count: false)
            result = Hash.new
            roots.each_record do |root_record|
                result[root_record['address']] = root_record

                root_record['references'].each do |addr|
                    ref_record = find_by_address(addr)
                    next if !ref_record

                    if with_keepalive_count
                        ref_record = ref_record.dup
                        count = 0
                        depth_first_visit(addr) { count += 1 }
                        ref_record['keepalive_count'] = count
                    end
                    result[addr] = ref_record
                end
            end
            MemoryDump.new(result)
        end

        # Remove all components that are smaller than the given number of nodes
        #
        # It really looks only at the number of nodes reachable from a root
        # (i.e. won't notice if two smaller-than-threshold roots have nodes in
        # common)
        def remove_small_components(max_size: 1)
            roots = self.addresses.to_set.dup
            leaves  = Set.new
            each_record do |r|
                refs = r['references']
                if refs.empty?
                    leaves << r['address']
                else
                    roots.subtract(r['references'])
                end
            end

            to_remove = Set.new
            roots.each do |root_address|
                component = Set[]
                queue = Set[root_address]
                while !queue.empty? && (component.size <= max_size)
                    address = queue.first
                    queue.delete(address)
                    next if component.include?(address)
                    component << address
                    queue.merge(address_to_record[address]['references'])
                end

                if component.size <= max_size
                    to_remove.merge(component)
                end
            end

            without(find_all { |r| to_remove.include?(r['address']) })
        end

        def stats
            unknown_class = 0
            by_class = Hash.new(0)
            each_record do |r|
                if klass = (r['class'] || r['type'] || r['root'])
                    by_class[klass] += 1
                else
                    unknown_class += 1
                end
            end
            return unknown_class, by_class
        end

        # Compute the set of records that are not in self but are in to
        #
        # @param [MemoryDump]
        # @return [MemoryDump]
        def diff(to)
            diff = Hash.new
            to.each_record do |r|
                address = r['address']
                if !@address_to_record.include?(address)
                    diff[address] = r
                end
            end
            MemoryDump.new(diff)
        end

        # Compute the interface between self and the other dump, that is the
        # elements of self that have a child in dump, and the elements of dump
        # that have a parent in self
        def interface_with(dump)
            result = Hash.new
            dump_border = Hash.new
            each_record do |r|
                found = false
                r['references'].each do |addr|
                    if child = dump.find_by_address(addr)
                        found = true
                        child = child.dup
                        dump_border[addr] = child
                        result[addr] = child
                    end
                end
                if found
                    result[r['address']] = r
                end
            end

            dump.ensure_graphs_computed
            dump_border.each do |addr, record|
                count = 0
                dump.depth_first_visit(addr) { |obj| count += 1 }
                record['keepalive_count'] = count
            end

            MemoryDump.new(result)
        end

        def replace_class_id_by_class_name(add_reference_to_class: false)
            MemDump.replace_class_address_by_name(self, add_reference_to_class: add_reference_to_class)
        end
    end
end

