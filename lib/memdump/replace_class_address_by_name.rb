module MemDump
    # Replace the address in the 'class' attribute by the class name
    def self.replace_class_address_by_name(dump, add_reference_to_class: false)
        class_names = Hash.new
        iclasses = Hash.new
        dump.each_record do |row|
            if row['type'] == 'CLASS' || row['type'] == 'MODULE'
                class_names[row['address']] = row['name']
            elsif row['type'] == 'ICLASS'
                iclasses[row['address']] = row
            end
        end

        iclass_size = 0
        while !iclasses.empty? && (iclass_size != iclasses.size)
            iclass_size = iclasses.size
            iclasses.delete_if do |_, r|
                if (klass = r['class']) && (class_name = class_names[klass])
                    class_names[r['address']] = "I(#{class_name})"
                    r['class'] = class_name
                    r['class_address'] = klass
                    if add_reference_to_class
                        (r['references'] ||= Array.new) << klass
                    end
                    true
                end
            end
        end

        dump.map do |r|
            if klass = r['class']
                r = r.dup
                r['class'] = class_names[klass] || klass
                r['class_address'] = klass
                if add_reference_to_class
                    (r['references'] ||= Array.new) << klass
                end
            end
            r
        end
    end
end
