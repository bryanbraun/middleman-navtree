require 'middleman-navtree/helpers'

module Middleman
  module NavTree

    # Extension namespace
    # @todo: Test the extension against a vanilla Middleman install.
    # @todo: Test the extension against a middleman-blog install.
    class NavTreeExtension < ::Middleman::Extension
      # All the options for this extension
      option :source_dir, 'source', 'The directory our tree will begin at.'
      option :data_file, 'tree.yml', 'The file we will write our directory tree to.'
      option :automatic_tree_updates, true, 'The tree.yml file will be updated automatically when source files are changed.'
      option :ignore_files, ['sitemap.xml', 'robots.txt'], 'A list of filenames we want to ignore when building our tree.'
      option :ignore_dir, ['assets'], 'A list of directory names we want to ignore when building our tree.'
      option :home_title, 'Home', 'The default link title of the home page (located at "/"), if otherwise not detected.'
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
        # Add the user's config directories to the "ignore_dir" option because
        # these are all things we won't need printed in a NavTree.
        options.ignore_dir << app.settings.js_dir
        options.ignore_dir << app.settings.css_dir
        options.ignore_dir << app.settings.fonts_dir
        options.ignore_dir << app.settings.images_dir
        options.ignore_dir << app.settings.helpers_dir
        options.ignore_dir << app.settings.layouts_dir
        options.ignore_dir << app.settings.partials_dir

        # Build a hash out of our directory information
        tree_hash = scan_directory(options.source_dir, options)

        # Promote any promoted files to the beginning of our hash.
        tree_hash = promote_files(tree_hash, options)

        # Write our directory tree to file as YAML.
        # @todo: This step doesn't rebuild during live-reload, which causes errors if you move files
        #        around during development. It may not be that hard to set up. Low priority though.
        if options.automatic_tree_updates
          data_path = app.settings.data_dir + '/' + options.data_file
          IO.write(data_path, YAML::dump(tree_hash))
        end
      end


      # Method for storing the directory structure in an ordered hash. See more on
      # ordered hashes at https://www.igvita.com/2009/02/04/ruby-19-internals-ordered-hash/
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
            original_path = path.sub(/^#{options.source_dir}/, '') + '/' + filename
            @existing_promotes << original_path
            next
          end

          full_path = File.join(path, filename)
          if File.directory?(full_path)
            # This item is a directory.
            # Check to see if we should ignore this directory.
            next if options.ignore_dir.include? filename

            # Loop through the method again.
            data.store(filename.gsub(' ', '%20'), scan_directory(full_path, options, filename))
          else

            # This item is a file.
            if !options.ext_whitelist.empty?
              # Skip any whitelisted extensions.
              next unless options.ext_whitelist.include? File.extname(filename)
            end

            original_path = path.sub(/^#{options.source_dir}/, '') + '/' + filename
            data.store(filename.gsub(' ', '%20'), original_path.gsub(' ', '%20'))
          end
        end

        # Return this level's data as a hash sorted by keys.
        return Hash[data.sort]
      end

      # Method for appending promoted files to the front of our source tree.
      # @todo: Currently, options.promote_files only expects a filename, which means that
      #        if multiple files in different directories have the same filename, they
      #        will both be promoted, and one will not appear (due to the 'no-two-identical
      #        -indices-in-a-hash' rule).
      # @todo: This system also assumes filenames only have a single extension,
      #        which may not be the case (like index.html.erb)
      # @todo: Basically, this is not elegent at all.
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