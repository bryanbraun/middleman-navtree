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
      # @todo: find a more elegant solution than just replacing "the filename" with ".html", or otherwise ensure
      #        it works for the other types of template files that middleman supports, and doesn't
      #        act weird on things like .js or .xml files. Maybe make a file extension whitelist? Blacklist?
      #        See: http://middlemanapp.com/basics/templates/#other-templating-languages
      # @todo: the order of the data is defined by the order in the hash, and technically, ruby hashes
      #        are unordered. This may be more robust if I defined an ordered hash type similar to
      #        this one in Rails: http://apidock.com/rails/ActiveSupport/OrderedHash
      def scan_directory(path, options, name=nil)
        data = {}
        Dir.foreach(path) do |filename|

          # Check to see if we should skip this file. We skip invisible files (starts with ".", ignored files, and promoted files
          # (which are handled later in the process).
          next if (filename[0] == '.')
          next if (filename == '..' || filename == '.')
          next if options.ignore_files.include? filename
          if options.promote_files.include? filename
            # Transform filepath (/source/directory/file.md => /directory/file.html)
            destination_path = path.sub(/^source/, '') + '/' + filename.chomp(File.extname(filename)) + '.html'
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
            # This item is a file... store the destination path.
            # Transform filepath (/source/directory/file.md => /directory/file.html)
            destination_path = path.sub(/^source/, '') + '/' + filename.chomp(File.extname(filename)) + '.html'
            data.store(filename, destination_path)
          end
        end

        return data
      end

      # Method for appending promoted files to the front of our source tree.
      # @todo: Currently, options.promote_files only expects a filename, which means that
      #        if multiple files in different directories have the same filename, they
      #        will both be promoted, and one will not appear (due to the 'no-two-identical
      #        -indices-in-a-hash' rule).
      def promote_files(tree_hash, options)

        if @existing_promotes.any?
          ordered_matches = []
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