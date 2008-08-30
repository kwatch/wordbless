require 'cgi'
require 'helpers/response_helper'
require 'tenjin'
require 'config/translation'

class Controller
  include ResponseHelper
  include Tenjin::ContextHelper
  include Tenjin::HtmlHelper

  alias h escape_xml

  def handle_request
    ## request parameters
    cgi = CGI.new
    params = {}
    cgi.params.each do |key, arr|
      params[key.intern] = key[-1] == ?* ? arr : arr.last
    end
    @cgi = cgi
    @params = params
    ## request_method, request_uri, base_url
    @request_method = ENV['REQUEST_METHOD']
    @request_uri = ENV['REQUEST_URI']
    @base_url = File.dirname(ENV['SCRIPT_NAME'])
    ## lang
    user_agent = ENV['HTTP_USER_AGENT'] || ''
    if    user_agent.empty?          ; @lang = 'en'
    elsif user_agent =~ /\bja-jp\b/  ; @lang = 'ja'
    else                             ; @lang = 'en'
    end
    ## action name and args
    pos = (@request_uri.index('?') || 0) - 1
    str = @request_uri[(@base_url.length+1)..pos]
    path_elems = str.split('/').collect {|s| CGI.unescape(s) }
    #if path_elems.empty?
    #  @action = 'index'
    #  @args   = []
    #else
    #  @action = path_elems[0]
    #  @args   = path_elems[1..-1]
    #end
    @action, @args = action_and_args(path_elems)
    ## handle action
    method_name = 'do_' + @action
    unless self.respond_to?(method_name)
      _404_Not_Found((t"%s: Unknown action.") % [@action.inspect])
      return false
    end
    invoke_handler(method_name)
  end

  def action_and_args(path_elems)
    if path_elems.empty?
      action = 'index'
      args   = []
    else
      action = path_elems[0]
      args   = path_elems[1..-1]
    end
    return action, args
  end

  def invoke_handler(method_name)
    before()
    ret = self.__send__(method_name)
    after()
    return ret
  end

  def before()
  end

  def after()
  end

  def for_insert(values)
    return values
  end

  def for_update(values)
    return values
  end

  def _render(template_name, context=self)
    engine = Tenjin::Engine.new(:postfix=>'.rbhtml', :layout=>:_layout, :path=>'views')
    return engine.render(template_name, context)
  end

  def render(template_name, context=self)
    _200_OK()
    print _render(template_name, context)
    return true
  end

  def render_view(template_name, context=self)
    print _render(template_name, context)
    return false
  end

  def redirect_to(url)
    _302_Found(url)
    print "<p>redirect to #{url}</p>\n"
    return true
  end

  def t(word)
    return word unless dict = DICTIONARY[@lang]
    return dict[word] || word
  end

  def open_session(new_session=nil, expires=nil)
    opts = {'new_session'=>new_session}
    if expires
      opts['session_expires'] = expires == true ? Time.now : expires
    end
    require 'cgi/session'
    begin
      session = CGI::Session.new(@cgi, opts)
    rescue ArgumentError
      session = nil
    end
    #require 'cgi/session/pstore'
    #session = CGI::Session.new(@cgi, 'database_manager'=>CGI::Session::PStore, 'new_session'=>new_session)
    yield(session)
    session.close() if session
  end

  def start_transaction_session(cookie_name='wbtsess')
    trans_session = @cgi.cookies[cookie_name][0]
    trans_session ||= renew_transaction_session(cookie_name)
    @transaction_session = trans_session
  end

  def renew_transaction_session(cookie_name='wbtsess')
    require 'digest/sha1'
    trans_session = Digest::SHA1.hexdigest(rand().to_s)
    @cgi.instance_eval do
      (@output_cookies ||= []) << CGI::Cookie.new(cookie_name, trans_session)
    end
    return trans_session
  end

  def transaction_key
    unless @transaction_session
      raise "Transaction session is not started."
    end
    require 'digest/sha1'
    return Digest::SHA1.hexdigest(@transaction_session)
  end

  def valid_transaction?
    trans = @cgi.params['_transaction'][0] || ''
    if trans.empty?
      _406_Not_Acceptable((t"Transaction key required."))
      return false
    end
    if trans != (t = transaction_key())
      _406_Not_Acceptable((t"Transaction key not matched."))
      return false
    end
    return true
  end

  def set_flash_message(message)
    ## TODO: implement
    @message = message
  end

end
