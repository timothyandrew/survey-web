class SurveysController < ApplicationController

  def index
    @surveys = Survey.paginate(:page => params[:page], :per_page => 10)
  end

  def destroy
    survey = Survey.find(params[:id])
    survey.destroy
    flash[:notice] = t "flash.survey_deleted"
    redirect_to(surveys_path)
  end

  def backbone_new
    @survey = Survey.new()
  end

  def backbone_create
    @survey = Survey.new(params[:survey])

    if @survey.save
      flash[:notice] = t "flash.survey_created"
      redirect_to surveys_build_path(:id => @survey.id)
    else
     render :backbone_new
   end
 end

 def build
  @survey = Survey.find(params[:id])
 end
end
