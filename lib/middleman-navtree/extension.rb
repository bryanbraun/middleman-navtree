require 'middleman-navtree/helpers'

module Middleman
  module NavTree

    # Extension namespace
    # @todo: This extension will need to support directory indexes, trailing slash, set: index_file, and
    #        any other standard config options I can think of, before it is released.
    # @todo: Test the extension against a vanilla Middleman install.
    # @todo: Test the extension against a middleman-blog install.
    class NavTreeExtension < ::Middleman::Extension
      # All the options for this extension
      option :source_dir, 'source', 'The directory our tree will begin at.'
      option :data_file, 'data/tree.yml', 'The file we will write our directory tree to.'
      option :ignore_files, ['sitemap.xml', 'robots.txt'], 'A list of filenames we want to ignore when building our tree.'
      option :ignore_dir, ['images', 'javascripts', 'stylesheets', 'layouts'], 'A list of directory names we want to ignore when building our tree.'
      option :promote_files, ['index.html.erb'], 'A list of files you want to push to the front of the tree (if they exist).'
      option :ext_whitelist, [], 'A whitelist of filename extensions (post-render) that we are allowing in our navtree. Example: [".html"]'


      # Helpers for use within templates and layouts.
      self.defined_helpers = [ ::Middleman::NavTree::Helpers ]

      def initialize(app, options_hash={}, &block)
        # Call super to build options from the options_hash
        super

        # Require libraries only when activated
        require 'yaml'
        require 'titleize'

        @existing_promotes = []

      end

      def after_configuration
        # Build a hash out of our directory information
        tree_hash = scan_directory(options.source_dir, options)

        # Promote any promoted files to the beginning of our hash.
        tree_hash = promote_files(tree_hash, options)

        # Write our directory tree to file as YAML.
        # @todo: This step doesn't rebuild during live-reload, which causes errors if you move files
        #        around during development. It may not be that hard to set up. Low priority though.
        IO.write(options.data_file, YAML::dump(tree_hash))
      end


      # Method for storing the directory structure in a hash.
      # @todo: the order of the data is defined by the order in the hash, and technically, ruby hashes
      #        are unordered. This may be more robust if I defined an ordered hash type similar to
      #        this one in Rails: http://apidock.com/rails/ActiveSupport/OrderedHash
      def scan_directory(path, options, name=nil)
        data = {}
        Dir.foreach(path) do |filename|

          # Check to see if we should skip this file. We skip invisible files
          # (starts with "."), ignored files, and promoted files (which are
          # handled later in the process).
          next if (filename[0] == '.')
          next if (filename == '..' || filename == '.')
          next if options.ignore_files.include? filename

          if options.promote_files.include? filename
            # Transform filepath (/source/directory/file.md => /directory/file.html)
            destination_path = path.sub(/^source/, '') + '/' + prep_filename(filename)
            @existing_promotes << destination_path
            next
          end

          full_path = File.join(path, filename)
          if File.directory?(full_path)
            # This item is a directory.
            # Check to see if we should ignore this directory.
            next if options.ignore_dir.include? filename

            # Loop through the method again.
            data.store(filename, scan_directory(full_path, options, filename))
          else
            # This item is a file.
            final_filename = prep_filename(filename)
            # We're whitelisting extensions, so only html files show up in the sourcetree.
            if !options.ext_whitelist.empty?
              next unless options.ext_whitelist.include? File.extname(final_filename)
            end

            # Transform filepath (/source/directory/file.md => /directory/file.html) and store it.
            destination_path = path.sub(/^source/, '') + '/' + final_filename
            data.store(filename, destination_path)
          end
        end

        return data
      end

      # This method renames filenames so they are always properly formatted for
      # looking up data in the sitemap.
      def prep_filename(filename)
        # Build an array of tilt formats to test our extensions against. The
        # master list is here:
        # http://middlemanapp.com/basics/templates/#other-templating-languages
        formats = ['html', 'slim', 'erb', 'rhtml', 'erubis', 'less', 'builder', 'liquid', 'markdown', 'mkd', 'md', 'textile', 'rdoc', 'radius', 'mab', 'nokogirl', 'coffee', 'wiki', 'creole', 'mediawiki', 'mw', 'yaji', 'styl', 'xml', 'css']
        md_formats = ['markdown', 'mkd', 'md']

        number_of_periods = filename.count '.'
        extensions = filename.split('.')

        if number_of_periods == 0
          # There's no extension, so we just return the filename unchanged.
          filename
        elsif number_of_periods == 1
          if formats.include? extensions[-1]
            # There's a single extension for us to replace with .html (because
            # that's what middleman will do). This is the most common situation.
            filename.chomp(extensions[-1]) << 'html'
          else
            # The extension wasn't in our list, so we just return the filename.
            filename
          end
        else
          # Has two+ extensions, like "test.html.md" or "1.1-test.html.md".
          # We only test the last two extensions, because middleman only changes
          # the last two.
          if formats.include?(extensions[-1]) && formats.include?(extensions[-2])
            if md_formats.include? extensions[-2]
              # Drop both extensions, and append "html".
              filename.chomp(extensions[-2] << '.' << extensions[-1]) << 'html'
            else
              # Only drop the last extension (since middleman keeps the 2nd to last).
              filename.chomp('.' << extensions[-1])
            end
          elsif formats.include? extensions[-1]
            # Replace the final extension with .html. Example: 1.1-test.md => 1.1-test.html. Note,
            # this still won't match the sitemap because of that middleman bug.
            filename.chomp(extensions[-1]) << 'html'
          else
            # No extensions were in our list, so we just return the filename.
            filename
          end
        end
      end

      # Method for appending promoted files to the front of our source tree.
      # @todo: Currently, options.promote_files only expects a filename, which means that
      #        if multiple files in different directories have the same filename, they
      #        will both be promoted, and one will not appear (due to the 'no-two-identical
      #        -indices-in-a-hash' rule).
      # @todo: This system also assumes filenames only have a single extension,
      #        which may not be the case (like index.html.erb)
      def promote_files(tree_hash, options)

        if @existing_promotes.any?
          ordered_matches = []

          # The purpose of this loop is to get my list of existing promotes
          # in the order specified in the options array, so it can be promoted
          # properly.
          options.promote_files.each do |filename|
            # Get filename without extension (index.md => index)
            filename_without_ext = filename.chomp(File.extname(filename))
            # Test against each existing_promote, and store matches
            @existing_promotes.each do |pathname|
              # Get another filename without extension from the pathname (/book/index.html => index)
              pathname_without_ext = File.basename(pathname, ".*")
              # Add matches to our ordered matches array.
              if filename_without_ext == pathname_without_ext
                ordered_matches << [filename, pathname]
              end
            end
          end
          # Promote all files found in both the promotes list and the file structure. This is an array
          # of arrays
          ordered_matches.reverse.each do |match|
            tree_hash = Hash[match[0], match[1]].merge!(tree_hash)
          end
        end

        return tree_hash
      end

    end
  end
end