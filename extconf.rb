require "mkmf-rice"
conf = RbConfig::MAKEFILE_CONFIG

if conf['target_cpu'] == 'arm64' && conf['target_os'].start_with?('darwin')
  $LIBPATH << '/opt/homebrew/lib'
  $INCFLAGS << ' -I/opt/homebrew/include '
  $LDFLAGS << ' -L/opt/homebrew/lib -lphonenumber '
  $CXXFLAGS << ' -I/opt/homebrew/include -std=c++17 '
end

create_makefile("pico_phone")