require 'kwery/model'

class Tag
  include Kwery::Model

  create_table('wb_tags') do |t|
    t.integer(:id) {|c| c.primary_key.serial }
    t.string(:name) {|c| c.not_null.unique }
    t.string(:desc)
    t.integer(:created_by) {|c| c.not_null.references('wb_accounts') }
    t.timestamp(:created_at) {|c| c.not_null }
    t.timestamp(:updated_at) {|c| c.not_null.default(:current_timestamp) }
    t.timestamp(:deleted_at)
  end

end
