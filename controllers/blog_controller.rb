require 'controllers/controller'
require 'kwery'
require 'kwery/adapters/mysql'


class BlogController < Controller

  def for_insert(values)
    values['created_by'] = @login_account ? @login_account['id'] : nil
    values['created_at'] = :current_timestamp
    values['updated_at'] = :current_timestamp
    return values
  end

  def for_update(values)
    values['updated_at'] = :current_timestamp
    return values
  end

  def before
    @title = 'WordBless Blog'
    check_login()
    start_transaction_session()
  end


  ####
  #### controller helpers
  ####

  #
  def check_login()
    ## TODO: implement
    @login_account = nil
    open_session do |session|
      if session
        if session['login_id'] && session['login_name'] && session['full_name']
          @login_account = {
            'id'        => session['login_id'].to_i,
            'name'      => session['login_name'],
            'full_name' => session['full_name'],
          }
        end
      end
    end
  end

  def logged_in?()
    return if @login_account
    _401_Unauthorized('Not logged in.')
    return false
  end

  def query
    unless @q
      require 'config/database'
      conn = db_connect()
      @q = Kwery::Query.new(conn)
      @q.output = $stderr if ENV['RUN_MODE'] == 'dev'
    end
    return @q
  end


  ####
  #### view helpers
  ####

  #
  def to_tag_links(tags)
    return [] unless tags
    return tags.collect {|tag|
      url = "#{@base_url}/search_by_tag_name/#{CGI.escape(tag['name'])}"
      "<a href=\"#{url}\">#{escape(tag['name'])}</a>"
    }
  end

  def text2html(text)
    return escape(text).gsub(/\r?\n/, "<br />\n")
  end


  ####
  #### model helpers
  ####

  #
  def get_account(name, password)
    require 'digest/sha1'
    digest = Digest::SHA1.hexdigest(password)
    q = query()
    account = q.get('wb_accounts') {|c| c.where(:name=>name, :password=>digest) }
    return account
  end

  def get_tags(q, post_id)
    return q.select('wb_tags, wb_taggings', 'wb_tags.*') {|c|
      c.where('wb_tags.id = wb_taggings.tag_id').where('wb_taggings.post_id =', post_id).order_by('wb_tags.id')
    }
  end

  def add_tags(q, post_id, tag_names)
    tag_names.each do |tag_name|
      tag = q.get('wb_tags', :name, tag_name)
      if tag
        tag_id = tag['id']
      else
        values = for_insert({:name=>tag_name})
        q.insert('wb_tags', values)
        tag_id = q.last_insert_id
      end
      values = for_insert({:tag_id=>tag_id, :post_id=>post_id})
      q.insert('wb_taggings', values)
    end
  end

  def get_posts_by_tag_id(q, tag_id, offset, count)
    return q.select('wb_posts, wb_taggings', 'wb_posts.*') {|c|
      c.where('wb_posts.id = wb_taggings.post_id')
      c.where('wb_taggings.tag_id = ', tag_id)
      c.order_by_desc('wb_posts.id')
      c.limit(offset, count) if offset && count
    }
  end

  def set_comment_counts(q, posts)
    id_list = posts.collect {|post| post['id'] }
    arrays = q.select('wb_comments', 'post_id, count(*) count', Array) {|c|
      c.where_in(:post_id, id_list).group_by(:post_id)
    }
    hash = {}
    arrays.each {|post_id, count| hash[post_id.to_i] = count }   # WHY .to_i required?
    posts.each {|post| post['comment_count'] = hash[post['id']] || 0 }
  end

  def set_tags_for_each_posts(q, posts)
    id_list = posts.collect {|post| post['id'] }
    tags = q.select('wb_tags, wb_taggings', 'wb_tags.*, wb_taggings.post_id post_id') {|c|
      c.where('wb_tags.id = wb_taggings.tag_id')
      c.where_in('wb_taggings.post_id', id_list)
      c.order_by('wb_taggings.id')
    }
    hash = tags.group_by('post_id')
    posts.each {|post| post['tags'] = hash[post['id'].to_s] || [] }  # WHY .to_s required?
  end

  def recent_posts(count=10)
    q = query()
    columns = 'id, title, created_by, created_at'
    posts = q.select('wb_posts', columns) {|c| c.order_by(:id).limit(0, count) }
    set_tags_for_each_posts(q, posts)
    return posts
  end

  def recent_comments(count=10)
    q = query()
    columns = 'id, post_id, user, created_at'
    comments = q.select('wb_comments', columns) {|c| c.order_by(:id).limit(0, count) }
    $stderr.puts "*** debug: comments=#{comments.inspect}"
    return comments
  end


  ####
  #### validators
  ####

  ##
  def validate_post(values, errors=[])
    ## title
    key = :title
    v = values.fetch(key, '').strip
    if    v.empty?        ; errors << [key, (t"%s is required.") % (t'Title')]
    elsif v.length > 255  ; errors << [key, (t"%s is too long.") % (t'Title')]
    end
    ## body
    key = :body
    v = values.fetch(key, '').strip
    if    v.empty?        ; errors << [key, (t"%s is required.") % (t'Body')]
    elsif v.length > 4095 ; errors << [key, (t"%s is too long.") % (t'Body')]
    end
    ##
    return errors
  end

  def validate_comment(values, errors=[])
    ## user
    key = :user
    v = values.fetch(key, '').strip
    if    v.empty?        ; errors << [key, (t"%s is required.") % (t'User name')]
    elsif v.length > 255  ; errors << [key, (t"%s is too long.") % (t'User name')]
    end
    ## body
    key = :body
    v = values.fetch(key, '').strip
    if    v.empty?        ; errors << [key, (t"%s is required.") % (t'Comment')]
    elsif v.length > 4096 ; errors << [key, (t"%s is too long.") % (t'Comment')]
    end
    ##
    return errors
  end

  def validate_login(values, errors=[])
    ## account name
    key = :name
    v = values.fetch(key, '').strip
    if    v.empty?        ; errors << [key, (t"%s is required.") % (t'Account name')]
    elsif v.length > 255  ; errors << [key, (t"%s is too long.") % (t'Account name')]
    end
    name = v
    ## password
    key = :password
    v = values.fetch(key, '').strip
    if    v.empty?        ; errors << [key, (t"%s is required.") % (t'Password')]
    elsif v.length > 255  ; errors << [key, (t"%s is too long.") % (t'Password')]
    end
    password = v
    ## check password
    @login_account = get_account(name, password)
    unless @login_account
      #errors << [nil, (t"Invalid account name or password.")]
      errors << [:password, (t"Invalid account name or password.")]
    end
    ##
    return errors
  end


  ####
  #### action handlers
  ####

  ##
  def do_login
    if @request_method != 'POST'
      #_200_OK()
      render(:login)
      return true
    end
    ## check transaction session
    return false unless valid_transaction?
    ## validation
    errors = validate_login(@params)
    if !errors.empty?
      @errors = errors
      _400_Bad_Request(false)
      render_view(:login)
      return false
    end
    ## start login session
    open_session(true) do |session|
      session['login_id']   = @login_account['id']
      session['login_name'] = @login_account['name']
      session['full_name']  = @login_account['full_name']
      session['login_at']   = Time.now
    end
    ## redirect
    #set_flash_message((t"Scceed to login."))
    url = @params[:backto]
    url = @base_url if !url || url.empty?
    redirect_to(url)
    return true
  end

  def do_logout
    open_session(nil, Time.now) do |session|
      session.delete() if session
    end
    @login_account = nil
    set_flash_message((t"Logged out."))
    render(:login)
    return true
  end

  def do_index
    offset = (@params[:offset] || 0).to_i
    count = 10
    q = query()
    posts = q.get_all('wb_posts') {|c| c.order_by_desc(:id).limit(offset, count) }
    if !posts.empty?
      q.bind_references_to(posts, 'wb_accounts', 'created_by', 'creator')
      #q.bind_referenced_from(posts, 'wb_comments', :post_id, 'comments')
      set_comment_counts(q, posts)
      set_tags_for_each_posts(q, posts)
    end
    @model_items = posts
    #_200_OK()
    render(:index)
    return true
  end

  def do_show
    ## post id
    post_id = @args.empty? ? nil : @args.shift
    if !post_id || post_id.empty?
      _400_Bad_Request((t"Post id required."))
      return false
    end
    ## post
    q = query()
    post = q.get('wb_posts', :id, post_id)
    unless post
      _404_Not_Found((t"Post not found."))
      return false
    end
    @model_item = post
    ## related objects
    post['creator'] = q.get('wb_accounts', :id, post['created_by'])
    post['comments'] = q.get_all('wb_comments', :post_id, post['id'])
    post['tags'] = get_tags(q, post['id'])
    ## render
    #_200_OK()
    render(:show)
    return true
  end

  def do_create
    return false unless logged_in?()
    ## login required
    unless @login_account
      _401_Unauthorized('Not logged in.')
      return false
    end
    ## show form
    if @request_method != 'POST'
      #_200_OK()
      render(:create)
      return true
    end
    ## canceled
    if @params[:_cancel]
      set_flash_message((t"Canceled."))
      redirect_to("#{@base_url}")
      return true
    end
    ## check transaction session
    return false unless valid_transaction?
    ## validation
    errors = validate_post(@params)
    if !errors.empty?
      @errors = errors
      _400_Bad_Request(false)
      render_view(:create)
      return false
    end
    ## insert
    values = for_insert(@params.slice(:title, :body))
    q = query()
    q.insert('wb_posts', values)
    ## add new tags
    post_id = q.last_insert_id
    new_tag_names = (@params[:'tags*'] || []).collect {|s| s.strip!; s.empty? ? nil : s }.compact
    add_tags(q, post_id, new_tag_names) if !new_tag_names.empty?
    ## redirect
    set_flash_message((t"New post created."))
    redirect_to("#{@base_url}/show/#{post_id}")
    return true
  end

  def do_edit
    return false unless logged_in?()
    ## post id
    post_id = @args.empty? ? nil : @args.shift
    if !post_id || post_id.empty?
      _400_Bad_Request((t"Post id required."))
      return false
    end
    ## post
    q = query()
    post = q.get('wb_posts', :id, post_id)
    unless post
      _404_Not_Found((t"Post not found."))
      return false
    end
    @model_item = post
    ## canceled
    if @params[:_cancel]
      set_flash_message((t"Canceled."))
      redirect_to("#{@base_url}/show/#{post['id']}")
      return true
    end
    ## tags
    post['tags'] = get_tags(q, post['id'])
    ## params
    ## show form
    if @request_method != 'POST'
      @params[:title] = post['title']
      @params[:body] = post['body']
      @params[:'tags*'] = post['tags'].collect {|tag| tag['name'] }
      #_200_OK()
      render(:edit)
      return true
    end
    ## check transaction session
    return false unless valid_transaction?
    ## validation
    errors = validate_post(@params)
    if !errors.empty?
      @errors = errors
      _400_Bad_Request(false)
      render_view(:edit)
      return false
    end
    ## update
    values = {}
    values[:title] = @params[:title] unless @params[:title] == post['title']
    values[:body]  = @params[:body]  unless @params[:body]  == post['body']
    if !values.empty?
      values = for_update(values)
      q = query()
      q.update('wb_posts', values, post['id'])
    end
    ## add new tags
    param_tags = (@params[:'tags*'] || []).collect {|s| (s = s.strip).empty? ? nil : s }.compact
    tag_names = post['tags'].collect {|tag| tag['name'] }
    now = :current_timestamp
    new_tag_names = param_tags - tag_names
    add_tags(q, post['id'], new_tag_names)
    ## delete obsolete tags
    obsolete_tag_names = tag_names - param_tags
    obsolete_tag_names.each do |tag_name|
      tag = post['tags'].find {|tag| tag['name'] == tag_name }
      q.delete('wb_taggings') {|c|
        c.where(:tag_id, tag['id']).where(:post_id, post['id'])
      }
    end
    ## redirect
    set_flash_message((t"Post data updated."))
    redirect_to("#{@base_url}/show/#{post['id']}")
    return true
  end

  def do_delete
    return false unless logged_in?()
    ## post id
    post_id = @args.empty? ? nil : @args.shift
    if !post_id || post_id.empty?
      _400_Bad_Request((t"Post id required."))
      return false
    end
    ## post
    q = query()
    post = q.get('wb_posts', :id, post_id)
    unless post
      _404_Not_Found((t"Post not found."))
      return false
    end
    @model_item = post
    ## delete
    q.delete('wb_posts', :id, post['id'])
    q.delete('wb_taggings', :post_id, post['id'])
    ## render
    set_flash_message((t"Post is deleted (id=%s, title: %s)") % [post['id'], post['title']])
    redirect_to("#{@base_url}/index")
  end

  def do_comment
    ## check method
    unless @request_method == 'POST'
      _405_Method_Not_Allowed((t"Only POST method allowed."))
      return false
    end
    ## check transaction session
    return false unless valid_transaction?
    ## post_id
    post_id = @args.empty? ? '' : @args.shift
    if post_id.empty?
      _400_Bad_Request((t"Post id required."))
      return false
    end
    ## post
    q = query()
    post = q.get('wb_posts', :id, post_id)
    unless post
      _404_Not_Found((t"Post not found."))
      return false
    end
    post_id = post['id']
    @model_item = post
    ## validation
    errors = validate_comment(@params)
    if errors && !errors.empty?
      @errors = errors
      _400_Bad_Request(false)
      render_view(:show)
      return false
    end
    ## insert
    values = for_insert(@params.slice(:user, :body))
    values.delete('created_by')
    #values.delete(:created_by)
    values[:post_id] = post_id
    q.insert('wb_comments', values)
    ## redirect
    comment_id = q.last_insert_id
    set_flash_message((t"Comment created."))
    redirect_to("#{@base_url}/show/#{post_id}\#c#{comment_id}")
    return true
  end

  def do_search_by_tag_name
    ## tag name
    if @args.length < 1 || (tag_name = @args.shift).empty?
      _400_Bad_Request((t"Tag name required."))
      return false
    end
    ## tag object
    q = query()
    tag = q.get('wb_tags', :name, tag_name)
    unless tag
      _400_Bad_Request((t"Tag name not found."))
      return false
    end
    ## search posts
    offset = count = nil
    posts = get_posts_by_tag_id(q, tag['id'], offset, count)
    if !posts.empty?
      q.bind_references_to(posts, 'wb_accounts', 'created_by', 'creator')
      set_comment_counts(q, posts)
      set_tags_for_each_posts(q, posts)
    end
    ## other tags
    all_tags = q.get_all('wb_tags') {|c| c.order_by(:name) }
    tuples = q.select('wb_posts, wb_taggings', 'wb_taggings.tag_id, count(*) count', Array) {|c|
      c.where('wb_posts.id = wb_taggings.post_id')
      c.group_by('wb_taggings.tag_id')
    }
    posts_count = Hash.new(0)
    tuples.each {|tag_id, count| posts_count[tag_id.to_i] = count }   # WHY?
    ## render
    @model_items = posts
    @tag         = tag
    @all_tags    = all_tags
    @posts_count = posts_count
    #_200_OK()
    render(:search)
    return true
  end

  def do_env
    return false unless logged_in?()
    html = ""
    html << "<table>\n"
    odd = false
    ENV.keys.sort.each do |name|
      val = ENV[name]
      odd = !odd
      color = odd ? '#FFFFDD' : '#EEEEEE'
      html << "<tr bgcolor=\"#{color}\"><th>#{name}</th><td>#{val}</td></tr>\n"
    end
    html << "</table>\n"
    _200_OK()
    print html
  end

end
