require 'kwery/model'

class Account
  include Kwery::Model

  create_table('wb_accounts') do |t|
    t.integer(:id)           {|c| c.primary_key.serial }
    t.string(:name)          {|c| c.not_null.unique }
    t.string(:password)      {|c| c.not_null }
    t.string(:full_name)     {|c| c.not_null }
    t.text(:desc)
    t.string(:email)         {|c| c.not_null }
    t.integer(:created_by)   {|c| c.not_null.references('wb_accounts') }
    t.timestamp(:created_at) {|c| c.not_null }
    t.timestamp(:updated_at) {|c| c.not_null.default(:current_timestamp) }
    t.timestamp(:deleted_at)
  end

end
