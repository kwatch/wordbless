##
## $Rev: 16 $
## $Release: 0.3.0 $
## copyright(c) 2007-2008 kuwata-lab.com all rights reserved.
## License: public domain
##

class CGIExceptionPrinter

  def initialize(skip_header=false, out=$stdout)
    @skip_header = skip_header
    @out = out
  end

  attr_accessor :skip_header, :out

  ## escape HTML characters
  def escape_html(s)
    s.to_s.gsub(/&/,'&amp;').gsub(/</,'&lt;').gsub(/>/,'&gt;').gsub(/"/,'&quot;')
  end

  alias h escape_html

  ## print http header
  def print_header()
    @out.print "Status: 500 Internal Error\r\n"
    @out.print "Content-Type: text/html\r\n"
    @out.print "X-CGI-Exception: 0.3.0\r\n"
    @out.print "\r\n"
  end

  ## print exception in HTML format
  def print_exception(ex)
    arr = ex.backtrace
    @out.print "<pre style=\"color:#CC0000\">"
    @out.print "<b>#{h(arr[0])}: #{h(ex.message)} (#{h(ex.class.name)})</b>\n"
    block = proc {|s| @out.print "        from #{h(s)}\n" }
    max = 20
    if arr.length <= max
      arr[1..-1].each(&block)
    else
      n = 5
      arr[1..(max-n)].each(&block)
      @out.print "           ...\n"
      arr[-n..-1].each(&block)
    end
    @out.print "</pre>"
  end

  def handle(exception)
    print_header() unless @skip_header
    print_exception(exception)
  end

end


class ModRubyExceptionPrinter < CGIExceptionPrinter

  ## print HTTP header (for mod_ruby)
  def print_header
    request = Apache::request
    request.status = 500
    request.status_line = '500 Internal Error'
    request.content_type = 'text/html'
    request.headers_out['X-CGI-Exception'] = '0.3.0'
    request.send_http_header
  end

  def print_exception(ex)
    super
    $stderr.write "#{ex.backtrace[0]}: #{ex.message} (#{ex.class.name})\n"
  end

end


if defined?(MOD_RUBY)

  class ::Apache::RubyRun  # :nodoc:
    ## if 'alias _handler_orig handler' statement is evaluated
    ## more than twice, handler() will cause stack over flow.
    unless self.method_defined?(:_handler_orig)
      alias _handler_orig handler
    end
    ## override handler() to catch and exception it to browser
    def handler(request)
      return _handler_orig(request)
    rescue Exception => ex
      #Apache.request.set_cgi_env unless ENV.key?("GATEWAY_INTERFACE")
      ModRubyExceptionPrinter.new().handle(ex)
      if defined?(EditorKicker)
        EditorKicker.handle(ex) #if ENV['EDITOR_KICKER']
      end
      #raise ex
      return ::Apache::OK
    end
    ## original
    #def handler(r)
    #  status = check_request(r)
    #  return status if status != OK
    #  filename = setup(r)
    #  load(filename, true)
    #  return OK
    #end
  end

else

  $_header_printed = false

  ## override $stdout.write() to detect whether HTTP header printed or not
  class << $stdout
    def write(*args)
      $_header_printed = true
      super(*args)
    end
  end

  ## when process exit, print exception if exception raised
  at_exit do
    if $!
      ex = $!
      CGIExceptionPrinter.new($_header_printed).handle(ex)
      if defined?(EditorKicker)
        EditorKicker.handle(ex) #if ENV['EDITOR_KICKER']
      end
    end
  end

end
