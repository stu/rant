
# progress.rb - Simple progress bar features for Rant.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

module Rant
    class ProgressCountdown
        attr_reader :total, :current
        def initialize(total, rant=nil)
            @total = total
            @step = @total / 10
            @fraction = 10
            @rant = rant
            @current = 0
        end
        def inc
            @current += 1
            if @step > 0 and @current % @step == 0
                @fraction -= 1
                print_progress "#@fraction " if @fraction >= 0
            end
        end
        private
        def print_progress(text)
            if @rant
                @rant.cmd_print(text)
            else
                print text
                $stdout.flush
            end
        end
    end # class ProgressCountdown
end # module Rant
