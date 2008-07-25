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
    x509 = File.join(package.target, 'include', 'openssl', 'x509.h')
    x509_vfy = File.join(package.target, 'include', 'openssl', 'x509_vfy.h')
    tmp_x509 = File.join(package.target, 'outinc', 'openssl', 'x509.h')
    tmp_x509_vfy = File.join(package.target, 'outinc', 'openssl', 'x509_vfy.h')

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

    file readme => [:extract_utils, :download, package.target] do
      # grab the files from the download task
      files = Rake::Task['dependencies:openssl:download'].prerequisites

      files.each { |f|
        extract(File.join(RubyInstaller::ROOT, f), package.target)
      }

      # remove bundled Makefile
      cd package.target do
        # rm_f 'Makefile'
      end
    end
    task :extract => [readme]

    # fix a missing header copy
    file tmp_x509 => x509 do |f|
      cp x509, tmp_x509
    end

    file tmp_x509_vfy => x509_vfy do |f|
      cp x509_vfy, tmp_x509_vfy
    end

    task :prepare => [:extract, tmp_x509, tmp_x509_vfy] do
      package_root = File.join(RubyInstaller::ROOT, package.target)
      include_dir = File.join(package_root, 'include', 'openssl')
      test_dir = File.join(package_root, 'test')

      cd include_dir do
        Dir.glob("**/*.h") do |file_link|
          if File.size(file_link).zero?
            Dir.glob("#{package_root}/{crypto,ssl}/**/#{file_link}").each do |real_file|
              cp real_file, include_dir
            end
          end
        end
      end

      cd test_dir do
        Dir.glob("*.c") do |file_link|
          if File.size(file_link).zero?
            Dir.glob("#{package_root}/{crypto,ssl}/**/#{file_link}").each do |real_file|
              cp real_file, test_dir
            end
          end
        end
      end

      cd package.target do
        Dir.glob("*.h") do |header|
          cp header, include_dir
        end
      end
    end

    file minfo => [:prepare] do
      cd package.target do
        msys_sh "make files"
      end
    end

    file makefile_mingw => [minfo] do
      cd package.target do
        msys_sh "perl util/mk1mf.pl no-asm dll shared Mingw32 > ms/mingw32a.mak"
      end
    end

    file makefile_msys => [makefile_mingw] do
      contents = File.read(makefile_mingw)
      contents.gsub!("CP=copy", "CP=cp")
      contents.gsub!("RM=del", "RM=rm")
      contents.gsub!(/(\S+)\\(\S+)/, '\\1/\\2')
      contents.gsub!(")\\", ")/")
      contents.gsub!("crypto\\", "crypto/")
      contents.gsub!("\\asm", "/asm")
      contents.gsub!(/if exist (\S+)(.*)/, "if [ -f \"\\1\" ]; then (\\2); fi")
      File.open(makefile_msys, 'w') do |f|
        f.write contents
      end
    end

    task :compile => [makefile_msys] do
      cd package.target do
        msys_sh "make -f ms/mingw32a-msys.mak"
      end
    end

    task :check => [:compile] do
      cd package.target do
        Dir.glob('out/*.exe').each do |test_app|
          sh test_app
        end
      end
    end
  end
end

task :download  => ['dependencies:openssl:download']
task :extract   => ['dependencies:openssl:extract']
