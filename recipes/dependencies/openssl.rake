require 'rake'
require 'rake/clean'

namespace(:dependencies) do
  namespace(:openssl) do
    package = RubyInstaller::OpenSsl
    directory package.target
    CLEAN.include(package.target)

    # reference to specific files inside OpenSSL
    readme = File.join(package.target, 'README')
    configure = File.join(package.target, 'Configure')
    makefile = File.join(package.target, 'Makefile')
    minfo = File.join(package.target, 'MINFO')
    makefile_mingw = File.join(package.target, 'ms', 'mingw32a.mak')
    makefile_msys = File.join(package.target, 'ms', 'mingw32a-msys.mak')
    def_libeay = File.join(package.target, 'ms', 'libeay32.def')
    def_ssleay = File.join(package.target, 'ms', 'ssleay32.def')

    # Put files for the :download task
    package.files.each do |f|
      file_source = "#{package.url}/#{f}"
      file_target = "downloads/#{f}"
      download file_target => file_source
      
      # depend on downloads directory
      file file_target => "downloads"
      
      # download task need these files as pre-requisites
      task :download => file_target
    end

    # Prepare the :sandbox, it requires the :download task
    task :extract => [:extract_utils, :download, package.target] do
      # grab the files from the download task
      files = Rake::Task['dependencies:openssl:download'].prerequisites

      files.each { |f|
        extract(File.join(RubyInstaller::ROOT, f), package.target)
      }
    end
  end
end

task :download  => ['dependencies:openssl:download']
task :extract   => ['dependencies:openssl:extract']
