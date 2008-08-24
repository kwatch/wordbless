require 'kwery/model'

class Comment
  include Kwery::Model

  create_table('wb_comments') do |t|
    t.integer(:id) {|c| c.primary_key.serial }
    t.string(:post_id) {|c| c.not_null.references('wb_posts') }
    t.string(:user) {|c| c.not_null }
    t.text(:body) {|c| c.not_null }
    t.timestamp(:created_at) {|c| c.not_null }
    t.timestamp(:updated_at) {|c| c.not_null.default(:current_timestamp) }
    t.timestamp(:deleted_at)
  end

end
