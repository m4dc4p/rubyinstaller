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
    makefile = File.join(package.target, 'Makefile')
    makefile_mingw = File.join(package.target, 'ms', 'mingw32a.mak')
    makefile_msys = File.join(package.target, 'ms', 'mingw32a-msys.mak')

    libcrypto = File.join(package.target, 'out', 'libcrypto.a')
    libssl = File.join(package.target, 'out', 'libssl.a')

    libeay32 = File.join(package.target, 'out', 'libeay32.a')
    ssleay32 = File.join(package.target, 'out', 'ssleay32.a')
    libeay32_def = File.join(package.target, 'ms', 'libeay32.def')
    ssleay32_def = File.join(package.target, 'ms', 'ssleay32.def')
    libeay32_dll = File.join(package.target, 'out', 'libeay32.dll')
    ssleay32_dll = File.join(package.target, 'out', 'ssleay32.dll')
    include_dir = File.join(package.target, 'outinc', 'openssl')

    installed_libeay32 = File.join(mingw.target, 'lib', 'libeay32.a')
    installed_ssleay32 = File.join(mingw.target, 'lib', 'ssleay32.a')
    installed_libeay32_dll = File.join(mingw.target, 'bin', 'libeay32.dll')
    installed_ssleay32_dll = File.join(mingw.target, 'bin', 'ssleay32.dll')
    installed_include_dir = File.join(mingw.target, 'include', 'openssl')

    install_files = {
      libeay32 => installed_libeay32,
      ssleay32 => installed_ssleay32,
      libeay32_dll => installed_libeay32_dll,
      ssleay32_dll => installed_ssleay32_dll,
      include_dir => installed_include_dir
    }

    asm_files = {
      'crypto/bn/asm/bn-win32.s' => 'bn-586.pl',
      'crypto/bn/asm/co-win32.s' => 'co-586.pl',
      'crypto/des/asm/d-win32.s' => 'des-586.pl',
      'crypto/des/asm/y-win32.s' => 'crypt586.pl',
      'crypto/bf/asm/b-win32.s' => 'bf-586.pl',
      'crypto/cast/asm/c-win32.s' => 'cast-586.pl',
      'crypto/rc4/asm/r4-win32.s' => 'rc4-586.pl',
      'crypto/md5/asm/m5-win32.s' => 'md5-586.pl',
      'crypto/sha/asm/s1-win32.s' => 'sha1-586.pl',
      'crypto/ripemd/asm/rm-win32.s' => 'rmd-586.pl',
      'crypto/rc5/asm/r5-win32.s' => 'rc5-586.pl',
      'crypto/cpu-win32.s' => 'x86cpuid.pl'
    }

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
        rm_f 'Makefile'
      end
    end
    task :extract => [readme]

    file configure => [readme] do
      contents = File.read(configure)
      contents.gsub!(":-mno-cygwin -Wl,--export-all -shared:.dll.a", ":-mno-cygwin -Wl,--export-all -shared:.dll.a")
      File.open(configure, 'w') do |f|
        f.write contents
      end
    end

    file makefile => [configure] do
      cd package.target do
        msys_sh "perl Configure mingw shared no-symlinks"
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

      cd package.target do
        Dir.glob("*.h") do |header|
          cp header, include_dir
        end
      end
    end

    # build the assembly files
    task :assemble => [:prepare]
    asm_files.each do |relative_asm, script|
      path = File.join(package.target, File.dirname(relative_asm))
      asm = File.basename(relative_asm)
      asm_with_path = File.join(path, asm)
      script_with_path = File.join(path, script)

      file asm_with_path => [script_with_path] do
        cd path do
          msys_sh "perl #{script} gaswin > #{asm}"
        end
      end
      task :assemble => [asm_with_path]
    end

    file openssl_conf_h => ['dependencies:openssl:assemble']
    file minfo => [openssl_conf_h] do
      cd package.target do
        msys_sh "perl util/mkfiles.pl > MINFO"
      end
    end

    file makefile_mingw => [minfo] do
      cd package.target do
        msys_sh "perl util/mk1mf.pl shlib gaswin Mingw32 > ms/mingw32a.mak"
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

    file ssleay32_def => [libssl] do
      cd package.target do
        msys_sh "perl util/mkdef.pl 32 ssleay > ms/ssleay32.def"
      end
    end

    file libeay32_def => [libcrypto] do
      cd package.target do
        msys_sh "perl util/mkdef.pl 32 libeay > ms/libeay32.def"
      end
    end

    file ssleay32_dll => [ssleay32_def, libeay32_dll] do
      cd package.target do
        msys_sh "dllwrap --dllname out/ssleay32.dll --output-lib out/ssleay32.a --def ms/ssleay32.def out/libssl.a out/libeay32.a"
      end
    end

    file libeay32_dll => [libeay32_def] do
      cd package.target do
        msys_sh "dllwrap --dllname out/libeay32.dll --output-lib out/libeay32.a --def ms/libeay32.def out/libcrypto.a -lwsock32 -lgdi32"
      end
    end
    task :compile => [libeay32_dll, ssleay32_dll]

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

    task :install => [:compile]
    install_files.each do |source, target|
      file target => [source] do
        cp_r source, target
      end
      task :install => [target]
    end

    task :all => [:download, :extract, :configure, :prepare, :assemble, :compile, :install]
  end
end

task :openssl => ['dependencies:openssl:all']
