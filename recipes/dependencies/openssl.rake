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

    file readme => [:extract_utils, :download, package.target] do
      # grab the files from the download task
      files = Rake::Task['dependencies:openssl:download'].prerequisites

      files.each { |f|
        extract(File.join(RubyInstaller::ROOT, f), package.target)
      }
    end
    task :extract => [readme]

    file configure => [:extract]
    file makefile => configure do
      cd package.target do
        msys_sh 'Configure mingw'
      end
    end
    task :configure => [makefile]

    task :prepare => [:configure] do
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
    end

    file minfo => [:extract] do
      cd package.target do
        msys_sh "perl util/mkfiles.pl > MINFO"
      end
    end

    file makefile_mingw => [minfo] do
      cd package.target do
        msys_sh "perl util/mk1mf.pl gaswin Mingw32 > ms/mingw32a.mak"
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

    file def_libeay do
      cd package.target do
        msys_sh "perl util/mkdef.pl 32 libeay > ms/libeay32.def"
      end
    end
    
    file def_ssleay do
      cd package.target do
        msys_sh "perl util/mkdef.pl 32 ssleay > ms/ssleay32.def"
      end
    end

    assembler_files = {
      'crypto/bn/asm/bn-win32.s' => 'bn-586.pl',
      'crypto/bn/asm/co-win32.s' => 'co-586.pl',
      'crypto/des/asm/d-win32.s' => 'des-586.pl',
      'crypto/des/asm/y-win32.s' => 'crypt586.pl',
      'crypto/bf/asm/b-win32.s' => 'bf-586.pl',
      'crypto/bn/asm/bn-win32.s' => 'bn-586.pl',
      'crypto/cast/asm/c-win32.s' => 'cast-586.pl',
      'crypto/rc4/asm/r4-win32.s' => 'rc4-586.pl',
      'crypto/md5/asm/m5-win32.s' => 'md5-586.pl',
      'crypto/sha/asm/s1-win32.s' => 'sha1-586.pl',
      'crypto/ripemd/asm/rm-win32.s' => 'rmd-586.pl',
      'crypto/rc5/asm/r5-win32.s' => 'rc5-586.pl',
      'crypto/bn/asm/bn-win32.s' => 'bn-586.pl',
      'crypto/cpu-win32.s' => 'x86cpuid.pl'
    }

    assembler_files.each do |asm, script|
      file File.join(package.target, asm) => File.join(package.target, File.dirname(asm), script) do
        cd File.join(package.target, File.dirname(asm)) do
          msys_sh "perl #{script} gaswin > #{File.basename(asm)}"
        end
      end
      task :assemble => File.join(package.target, asm)
    end

    task :compile => [makefile_msys, def_libeay, def_ssleay, :assemble] do
      cd package.target do
        msys_sh "make -f ms/mingw32a-msys.mak"
      end
    end

=begin
    # Prepare the :sandbox, it requires the :download task
    task :extract => [:extract_utils, :download, package.target] do
      # grab the files from the download task
      files = Rake::Task['dependencies:openssl:download'].prerequisites

      files.each { |f|
        extract(File.join(RubyInstaller::ROOT, f), package.target)
      }
    end
=end
  end
end

task :download  => ['dependencies:openssl:download']
task :extract   => ['dependencies:openssl:extract']
