class DropDownQuestionDecorator < QuestionDecorator
  decorates :drop_down_question
  delegate_all

  def input_tag(f, opts={})
    super(f,  :as => :select,
              :collection => model.options.map { |o| [o.content, o.content, {'data-option-id' => o.id }] },
              :input_html => { :disabled => opts[:disabled] })
  end
end
