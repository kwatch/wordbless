require 'kwery/model'

class Tagging
  include Kwery::Model

  create_table('wb_taggings') do |t|
    t.integer(:id) {|c| c.primary_key.serial }
    t.references(:post_id, 'wb_posts') {|c| c.not_null }
    t.references(:tag_id, 'wb_tags') {|c| c.not_null }
    t.references(:created_by, 'wb_acconts') {|c| c.not_null }
    t.timestamp(:created_at) {|c| c.not_null }
    t.timestamp(:updated_at) {|c| c.not_null.default(:current_timestamp) }
    t.timestamp(:deleted_at)
    t.unique(:post_id, :tag_id)
  end

end
