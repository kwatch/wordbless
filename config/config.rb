
is_localhost = ENV['SERVER_NAME'] == 'localhost' || ENV['SERVER_ADDR'] == '127.0.0.1'

ENV['RUN_MODE'] ||= is_localhost ? 'dev' : nil

if is_localhost
  require 'cgi_exception'
  require 'editor_kicker'
  ## for TextMate
  #mate = '/Applications/TextMate.app/Contents/Resources/mate'
  #ENV['EDITOR_KICKER'] = "#{mate} -l %s '%s'"
  ## for Emacs
  emacsclient = '/Applications/Emacs.app/Contents/MacOS/bin/emacsclient'
  ENV['EDITOR_KICKER'] = "#{emacsclient} -n -s /tmp/emacs501/server +%s '%s'"
end
