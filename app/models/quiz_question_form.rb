class QuizQuestionForm
  include ActiveModel::Validations
  include ActiveModel::Conversion
  extend ActiveModel::Naming
  
  attr_accessor :question, :answer, :author_comments, :reviewer_comments, :type, :id, :name, :status
  validates_presence_of :question, :answer, :type
  
  def initialize(attributes = {})
    attributes.each do |name, value|
      send("#{name}=", value)
    end
  end
  
  def persisted?
    false
  end
  
end