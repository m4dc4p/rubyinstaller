require 'rake'
require 'rake/clean'

namespace(:dependencies) do
  namespace(:openssl) do
    package = RubyInstaller::OpenSsl
    mingw = RubyInstaller::MinGW
    directory package.target
    CLEAN.include(package.target)

    # reference to specific files inside OpenSSL
    readme = File.join(package.target, 'README')
    configure = File.join(package.target, 'Configure')
    openssl_conf_h = File.join(package.target, 'include', 'openssl', 'opensslconf.h')
    minfo = File.join(package.target, 'MINFO')
    makefile_mingw = File.join(package.target, 'ms', 'mingw32a.mak')
    makefile_msys = File.join(package.target, 'ms', 'mingw32a-msys.mak')
    libcrypto = File.join(package.target, 'out', 'libcrypto.a')
    libssl = File.join(package.target, 'out', 'libssl.a')
    installed_libcrypto = File.join(mingw.target, 'lib', 'libcrypto.a')
    installed_libssl = File.join(mingw.target, 'lib', 'libssl.a')

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

    task :prepare => [:extract] do
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

    file openssl_conf_h => [:prepare]
    file minfo => [openssl_conf_h] do
      cd package.target do
        msys_sh "perl util/mkfiles.pl > MINFO"
      end
    end

    file makefile_mingw => [minfo] do
      cd package.target do
        msys_sh "perl util/mk1mf.pl shlib Mingw32 > ms/mingw32a.mak"
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
      contents.gsub!("\\usr\\local", "/mingw")
      contents.gsub!(/if exist (\S+)(.*)/, "if [ -f \"\\1\" ]; then (\\2); fi")
      File.open(makefile_msys, 'w') do |f|
        f.write contents
      end
    end

    file libssl => [libcrypto]
    file libcrypto => [makefile_msys] do
      cd package.target do
        msys_sh "make -f ms/mingw32a-msys.mak"
      end
    end
    task :compile => [libcrypto]

    task :check => [:compile] do
      test_dir = File.join(package.target, 'out')
      cd test_dir do
        Dir.glob('*.exe').each do |test_app|
          if test_app =~ /evp/
            sh "#{test_app} ../test/evptests.txt"
          elsif test_app =~ /openssl/
            sh "#{test_app} version"
          else
            sh test_app
          end
        end
      end
    end

    file installed_libssl => [installed_libcrypto]
    file installed_libcrypto => [libcrypto] do
      include_dir = File.join(package.target, 'outinc', 'openssl')
      target_include_dir = File.join(mingw.target, 'include')

      cp libcrypto, installed_libcrypto
      cp libssl, installed_libssl
      cp_r include_dir, target_include_dir
    end
    task :install => [installed_libcrypto]

    task :all => [:download, :extract, :prepare, :compile, :install]
  end
end

task :openssl => ['dependencies:openssl:all']
