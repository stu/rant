
# inspect.rb - Custom inspect method for Rant::FileList instances.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

module Rant
    class FileList
        # Note that the default Object#inspect implementation is
        # available as +object_inspect+.
        def inspect
            # empirisch ermittelt ;)
            s = "#<#{self.class}:0x%x " % (object_id << 1)

            s << "glob:" << (glob_dotfiles? ? "all" : "unix") << " "
            if ix = ignore_rx
                is = ix.source.dup
                is.gsub!(/ +/, ' ')
                is.gsub!(/\n/, '\n')
                is.gsub!(/\t/, '\t')
                is[10..-1] = "..." if is.length > 12
                s << "i:#{is} "
            end

            if @pending
                s << "res:#{@actions.size} "
            end

            unless @keep.empty?
                s << "keep:#{@keep.size} "
            end

            s << "entries:#{items.size}"
            if @items.size > 0
                s << "["
                if @items.size == 1
                    is = @items.first.dup
                    is[15..-1] = "..." if is.length > 16
                    is = '"' << is << '"'
                else
                    fs = @items.first.dup
                    fs[11..-1] = "..." if fs.length > 12
                    fs = '"' << fs << '"'
                    ls = @items.last.dup
                    ls[0..-11] = "..." if ls.length > 12
                    ls = '"' << ls << '"'
                    if @items.size == 2
                        is = "#{fs}, #{ls}"
                    else
                        is = "#{fs}, ..., #{ls}"
                    end
                end
                s << "#{is}]"
            end
            s << ">"
        end
    end # class FileList
end # module Rant
