module MemDump
    # Replace the address in the 'class' attribute by the class name
    def self.replace_class_address_by_name(dump, add_reference_to_class: false)
        class_names = Hash.new
        dump.each_record do |row|
            if row['type'] == 'CLASS' || row['type'] == 'MODULE'
                class_names[row['address']] = row['name']
            end
        end

        dump.each_record.map do |r|
            if klass = r['class']
                r['class'] = class_names[klass] || klass
                r['class_address'] = klass
                if add_reference_to_class
                    (r['references'] ||= Array.new) << klass
                end
            end
            if r['type'] == 'ICLASS'
                r['class'] = "I(#{r['class']})"
            end
            r
        end
    end
end
