module Middleman
  module NavTree
    # NavTree-related helpers that are available to the Middleman application in +config.rb+ and in templates.
    module Helpers

      #  A recursive helper for converting source tree data from into HTML
      def tree_to_html(value, depth = Float::INFINITY, key = nil, level = 0)
        html = ''

        if value.is_a?(String)
          # This is a child item (a file). Get the Sitemap resource for this file.
          # note: sitemap.extensionless_path converts the path to its 'post-build' extension.
          this_resource = sitemap.find_resource_by_path(sitemap.extensionless_path(value))
          # Define string for active states.
          active = this_resource == current_page ? 'active' : ''
          title = discover_title(this_resource)
          link = link_to(title, sitemap.extensionless_path(value))
          html << "<li class='child #{active}'>#{link}</li>"
        else
          # This is a directory.
          if key.nil?
            # The first level is the source directory, so it has no key and needs no list item.
            value.each do |newkey, child|
              html << tree_to_html(child, depth, newkey, level + 1)
            end
          # Continue rendering deeper levels of the tree, unless restricted by depth.
          elsif depth >= (level + 1)
            # This directory has a key and should be listed in the page hieararcy with HTML.
            dir_name = key
            html << "<li class='parent'><span class='parent-label'>#{dir_name.gsub(/-/, ' ').gsub(/_/, ' ').titleize}</span>"
            html << '<ul>'

            # Loop through all the directory's contents.
            value.each do |newkey, child|
              html << tree_to_html(child, depth, newkey, level + 1)
            end
            html << '</ul>'
            html << '</li>'
          end
        end

        return html
      end

      # Pagination helpers
      # @todo: One potential future feature is previous/next links for paginating on a
      #        single level instead of a flattened tree. I don't need it but it seems pretty easy.
      def previous_link(sourcetree)
        pagelist = flatten_source_tree(sourcetree)
        position = get_current_position_in_page_list(pagelist)
        # Skip link generation if position is nil (meaning, the current page isn't in our
        # pagination pagelist).
        if position
          prev_page = pagelist[position - 1]
          options = {:class => "previous"}
          unless first_page?(pagelist)
            link_to("Previous", prev_page, options)
          end
        end
      end

      def next_link(sourcetree)
        pagelist = flatten_source_tree(sourcetree)
        position = get_current_position_in_page_list(pagelist)
        # Skip link generation if position is nil (meaning, the current page isn't in our
        # pagination pagelist).
        if position
          next_page = pagelist[position + 1]
          options = {:class => "next"}
          unless last_page?(pagelist)
            link_to("Next", next_page, options)
          end
        end
      end

      # Helper for use in pagination methods.
      def first_page?(pagelist)
        return true if get_current_position_in_page_list(pagelist) == 0
      end

      # Helper for use in pagination methods.
      def last_page?(pagelist)
        return true if pagelist[get_current_position_in_page_list(pagelist)] == pagelist[-1]
      end

      # Method to flatten the source tree, for use in pagination methods.
      # Note, I could do this with a lot less code using Glob. I should refactor
      # in the future. See http://stackoverflow.com/a/2370823/1154642.
      def flatten_source_tree(value, k = [], level = 0, flat_tree = [])

        if value.is_a?(String)
          # This is a child item (a file).
          flat_tree.push(sitemap.extensionless_path(value))
        elsif value.is_a?(Hash)
          # This is a parent item (a directory).
          value.each do |key, child|
            flatten_source_tree(child, key, level + 1, flat_tree)
          end
        end

        return flat_tree
      end

      # Helper for use in pagination methods.
      def get_current_position_in_page_list(pagelist)
        pagelist.each_with_index do |page_path, index|
          if page_path == "/" + current_page.path
            return index
          end
        end
        # If we reach this line, the current page path wasn't in our page list and we'll
        # return false so the link generation is skipped.
        return FALSE
      end

      # Utility helper for getting the page title
      # Based on this: http://forum.middlemanapp.com/t/using-heading-from-page-as-title/44/3
      # 1) Use the title from frontmatter metadata, or
      # 2) peek into the page to find the H1, or
      # 3) Use the home_title option (if this is the home page--defaults to "Home"), or
      # 4) fallback to a filename-based-title
      def discover_title(page = current_page)
        if page.data.title
          return page.data.title # Frontmatter title
        elsif page.url == '/'
          return extensions[:navtree].options[:home_title]
        elsif match = page.render({:layout => false}).match(/<h.+>(.*?)<\/h1>/)
          return match[1] # H1 title
        else
          filename = page.url.split(/\//).last.titleize
          return filename.chomp(File.extname(filename))
        end
      end

    end
  end
end