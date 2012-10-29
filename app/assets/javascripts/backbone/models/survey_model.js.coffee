# Wr
class SurveyBuilder.Models.SurveyModel extends Backbone.RelationalModel  
  initialize:(@survey_id) ->
    @question_models = []
    this.urlRoot = "/api/surveys"
    this.set('id', survey_id)

  add_new_question_model:(type, parent) ->
    switch type
      when 'MultiChoiceQuestion'
        question_model = new SurveyBuilder.Models.QuestionWithOptionsModel({type: 'MultiChoiceQuestion'})
      when 'DropDownQuestion'
        question_model = new SurveyBuilder.Models.QuestionWithOptionsModel({type: 'DropDownQuestion'})
      when 'RadioQuestion'
        question_model = new SurveyBuilder.Models.QuestionWithOptionsModel({type: 'RadioQuestion'})
      else
        question_model = new SurveyBuilder.Models.QuestionModel({type: type})

    question_model.set('survey_id' : this.survey_id)
    @set_order_number_for_question(question_model, parent)
    question_model.set('parent_id' : parent.get('id')) if parent
    @question_models.push question_model
    question_model.on('destroy', this.delete_question_model, this)
    question_model

  next_order_number: ->
    if _(@question_models).isEmpty()
      0
    else
      _.max(@question_models, (question_model) ->
        question_model.get "order_number"
      ).get('order_number') + 1

  set_order_number_for_question: (model, parent) ->
    if parent
      model.set('order_number' : parent.next_sub_question_order_number())
    else
      model.set('order_number' : this.next_order_number())

  save: ->
    super({}, {error: this.error_callback, success: this.success_callback})

  success_callback: (model, response) =>
    this.errors = []
    this.trigger('change:errors')
    this.trigger('save:completed')

  error_callback: (model, response) =>
    this.errors = JSON.parse(response.responseText)
    this.trigger('change:errors')

  save_all_questions: ->
    for question_model in @question_models
      question_model.save_model()

  delete_question_model: (model) ->
    @question_models = _(@question_models).without(model)

  has_errors: ->
    _.any(@question_models, (question_model) -> question_model.has_errors())

SurveyBuilder.Models.SurveyModel.setup()
