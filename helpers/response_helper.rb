module ResponseHelper

  module_function

  def _200_OK
    print @cgi.header('Content-Type'=>'text/html; charset=UTF-8')
  end

  def _302_Found(url)
    print @cgi.header('Status'=>'302 Found', 'Location'=>url)
  end

  def _4xx(status, message)
    print @cgi.header('Status'=>status, 'Content-Type'=>'text/html; charset=UTF-8')
    unless message == false
      #@status = status
      #@message = message
      #render_view(:_4xx)
      puts "<html>"
      puts "<head><title>#{escape(status)}</title></head>"
      puts "<body><h2>#{escape(status)}</h2><p>#{escape(message.to_s)}</p></body>"
      puts "</html>"
    end
    return false
  end
  private :_4xx

  def _400_Bad_Request(message=nil)
    return _4xx('400 Bad Request', message)
  end

  def _401_Unauthorized(message=nil)
    return _4xx('401 Unauthorized', message)
  end

  def _403_Forbidden(message=nil)
    return _4xx('403 Forbidden', message)
  end

  def _404_Not_Found(message=nil)
    return _4xx('404 Not Found', message)
  end

  def _405_Method_Not_Allowed(message=nil)
    return _4xx('405 Method Not Allowed', message)
  end

  def _406_Not_Acceptable(message=nil)
    return _4xx('406 Not Acceptable', message)
  end

end
