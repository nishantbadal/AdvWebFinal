class Order < ActiveRecord::Base
	belongs_to :user
end

class User < ActiveRecord::Base
	has_many :sku
end

class Sku < ActiveRecord::Base
	belongs_to :user
	def self.search(name)
		where('name like :pat', :pat => "%#{name}%")
	end
end

