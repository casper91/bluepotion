# mq.wrap(rmq.root_view).find(ButtonView)
module RubyMotionQuery

  class RMQ
    def initialize
      @selected_dirty = true
    end

    def context=(value)
      if value
        #if value.is_a?(Activity)
          #@context = RubyMotionQuery::RMQ.weak_ref(value)
        #elsif value.is_a?(View)
          @context = value
        #else
          #debug.log_detailed('Invalid context', objects: {value: value})
        #end
      else
        @context = nil
      end
      @context
    end

    def context
      @context
    end

    def parent_rmq
      @_parent_rmq
    end
    def parent_rmq=(value)
      #debug.assert(value.is_a?(RMQ) || value.nil?, 'Invalid parent_rmq', { value: value })
      @_parent_rmq = value
    end

    # Do not use
    def selected=(value)
      @_selected = value
      @selected_dirty = false
    end

    def root?
      (selected.length == 1) && (selected.first == @context)
    end

    def context_or_context_view
      if @context.is_a?(Activity)
        @context.view
      else
        @context
      end
    end

    def get
      sel = self.selected
      if sel.length == 1
        sel.first
      else
        sel
      end
    end

    def origin_views
      if pq = self.parent_rmq
        pq.selected
      else
        root_view
      end
    end

    def wrap(*views)
      views.flatten!
      views.select!{ |v| v.is_a?(View) } # TODO Fake view here
      RMQ.create_with_array_and_selectors(views, views, views.first, self)
    end

    def log(opt = nil)
      if opt == :tree
        puts tree_to_s(selected)
        return
      end

      wide = (opt == :wide)
      out =  "\n object_id   | class                 | style_name              | frame                           |"
      out << "\n" unless wide
      out <<   " sv id       | superview             | subviews count          | tags                            |"
      line =   " - - - - - - | - - - - - - - - - - - | - - - - - - - - - - - - | - - - - - - - - - - - - - - - - |\n"
      out << "\n"
      out << line.chop if wide
      out << line

      selected.each do |view|
        out << " #{view.object_id.to_s.ljust(12)}|"
        out << " #{view.class.name[0..21].ljust(22)}|"
        out << " #{(view.style_name || '')[0..23].ljust(24)}|" # TODO change to real stylname

        s = ""
        #if view.origin
          #format = '#0.#'
          #s = " {l: #{RMQ.format.numeric(view.origin.x, format)}"
          #s << ", t: #{RMQ.format.numeric(view.origin.y, format)}"
          #s << ", w: #{RMQ.format.numeric(view.size.width, format)}"
          #s << ", h: #{RMQ.format.numeric(view.size.height, format)}}"
        #end
        out << s.ljust(33)
        out << '|'

        out << "\n" unless wide
        out << " #{view.superview.object_id.to_s.ljust(12)}|"
        out << " #{(view.superview ? view.superview.class.name : '')[0..21].ljust(22)}|"
        out << " #{view.subviews.length.to_s.ljust(23)} |"
        #out << "  #{view.subviews.length.to_s.rjust(8)} #{view.superview.class.name.ljust(20)} #{view.superview.object_id.to_s.rjust(10)}"
        #out << " #{view.rmq_data.tag_names.join(',').ljust(32)}|"
        out << "\n"
        out << line unless wide
      end

      out << "RMQ #{self.object_id}. #{self.count} selected. selectors: #{self.selectors}"

      puts out
    end

    def tree_to_s(selected_views, depth = 0)
      out = ""

      selected_views.each do |view|

        if depth == 0
          out << "\n"
        else
          0.upto(depth - 1).each do |i|
            out << (i == (depth - 1) ? '    ├' : '    │')
          end
        end

        out << '───'

        out << " #{view.class.name[0..21]}"
        out << "  ( #{view.style_name[0..23]} )" if view.style_name
        out << "  #{view.object_id}"
        #out << "  [ #{view.rmq_data.tag_names.join(',')} ]" if view.rmq_data.tag_names.length > 0

        #if view.origin
          #format = '#0.#'
          #s = "  {l: #{RMQ.format.numeric(view.origin.x, format)}"
          #s << ", t: #{RMQ.format.numeric(view.origin.y, format)}"
          #s << ", w: #{RMQ.format.numeric(view.size.width, format)}"
          #s << ", h: #{RMQ.format.numeric(view.size.height, format)}}"
          #out << s
        #end

        out << "\n"
        out << tree_to_s(view.subviews, depth + 1)
      end

      out
    end

    def inspect
      out = "RMQ #{self.object_id}. #{self.count} selected. selectors: #{self.selectors}. .log for more info"
      out << "\n[#{selected.first}]" if self.count == 1
      out
    end

    def context_or_context_view
      #if @context.is_a?(Activity)
        #@context.view
      #else
        @context
      #end
    end

    def selected
      if @selected_dirty
        @_selected = []

        if RMQ.is_blank?(self.selectors)
          @_selected << context_or_context_view
        else
          working_selectors = self.selectors.dup
          extract_views_from_selectors(@_selected, working_selectors)

          unless RMQ.is_blank?(working_selectors)
            subviews = all_subviews_for(root_view)
            subviews.each do |subview|
              @_selected << subview if match(subview, working_selectors)
            end
          end

          @_selected.uniq!
        end

        @selected_dirty = false
      else
        @_selected ||= []
      end

      @_selected
    end

    def extract_views_from_selectors(view_container, working_selectors)
      unless RMQ.is_blank?(working_selectors)
        working_selectors.delete_if do |selector|
          if selector.is_a?(View)
            view_container << selector
            true
          end
        end
      end
    end

    def all_subviews_for(view)
      out = []
      if view.subviews
        view.subviews.each do |subview|
          out << subview
          out << all_subviews_for(subview)
        end
        out.flatten!
      end

      out
    end

    def all_superviews_for(view, out = [])
      if (sv = view.superview)
        out << sv
        all_superviews_for(sv, out)
      end
      out
    end

  end # RMQ
end