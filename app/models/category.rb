class Category < ActiveRecord::Base
  belongs_to :parent, :class_name => Option
  belongs_to :category
  attr_accessible :content, :survey_id, :order_number, :category_id, :parent_id
  has_many :questions, :dependent => :destroy
  has_many :categories, :dependent => :destroy
  validates_presence_of :content
  belongs_to :survey
end