module MemDump
    def self.stats(memdump)
        unknown_class = 0
        by_class = Hash.new(0)
        memdump.each_record do |r|
            if klass = (r['class'] || r['type'] || r['root'])
                by_class[klass] += 1
            else
                unknown_class += 1
            end
        end
        return unknown_class, by_class
    end
end

