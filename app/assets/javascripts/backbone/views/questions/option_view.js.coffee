SurveyBuilder.Views.Questions ||= {}

#  The settings of a single option in the settings pane
class SurveyBuilder.Views.Questions.OptionView extends Backbone.View
  events:
    'keyup': 'update_model'

  initialize: (model) ->
    this.model = model

  render: ->
    template = $('#option_template').html()
    $(this.el).html(Mustache.render(template, this.model.toJSON()))
    return this

  update_model: (event) ->
    input = $(event.target)
    this.model.set({content: input.val()})
    event.stopImmediatePropagation()