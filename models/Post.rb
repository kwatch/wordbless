require 'kwery/model'

class Post
  include Kwery::Model

  create_table('wb_posts') do |t|
    t.integer(:id) {|c| c.primary_key.serial }
    t.string(:title) {|c| c.not_null }
    t.text(:body) {|c| c.not_null }
    t.integer(:created_by) {|c| c.not_null.references('wb_accounts') }
    t.timestamp(:created_at) {|c| c.not_null }
    t.timestamp(:updated_at) {|c| c.not_null.default(:current_timestamp) }
    t.timestamp(:deleted_at)
  end

  attr_accessor :comments, :comment_count, :creator

end
