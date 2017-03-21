require 'rgl/adjacency'
require 'rgl/dijkstra'

require "memdump/version"
require 'memdump/json_dump'
require 'memdump/memory_dump'

require 'memdump/cleanup_references'
require 'memdump/common_ancestor'
require 'memdump/convert_to_gml'
require 'memdump/out_degree'
require 'memdump/remove_node'
require 'memdump/replace_class_address_by_name'
require 'memdump/root_of'
require 'memdump/stats'
require 'memdump/subgraph_of'

module MemDump
    def self.pry(dump)
        binding.pry
    end
end
