namespace :gmatic do
  BIN_ZIP = "zip"

  def _system (command)
    puts "=> #{command}"
    system(command)
  end

  # Parses the version number from the .toc file so we can build the
  # output archive filename, or returns nil if an error occurred.
  #
  def _get_version_number
    File.open("Guildomatic/Guildomatic.toc", "r") do |io|
      while (line = io.gets) do
        if (line =~ /^## Version: (.*)$/)
          break $1
        end
      end
    end

  rescue => e
    nil
  end

  desc "Builds the zip file archive for distribution."
  task :dist do
    puts "Building zip file archive for distribution."
    version = _get_version_number

    if version
      zip_name = "gmatic_#{version}.zip"
      command = "#{BIN_ZIP} -r #{zip_name} Guildomatic -x \*.DS_Store -x Guildomatic/Guildomatic_static.lua"
      _system(command)

      puts "Archive complete."

    else
      STDERR.puts "Failed to get module version number."
    end
  end
end
