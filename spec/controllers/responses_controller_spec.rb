require 'spec_helper'

describe ResponsesController do
  let(:survey) { FactoryGirl.create(:survey_with_questions, :organization_id => 1) }
  before(:each) do
    sign_in_as('cso_admin')
    session[:user_info][:org_id] = 1
  end

  context "POST 'create'" do
    let(:survey) { FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)}
    let(:question) { FactoryGirl.create(:question)}

    it "saves the response" do
      expect {
        post :create, :survey_id => survey.id

      }.to change { Response.count }.by(1)
    end

    it "saves the response with blank as true" do
      post :create, :survey_id => survey.id
      Response.last.should be_blank
    end

    it "saves the response to the right survey" do
      post :create, :survey_id => survey.id
      assigns(:response).survey.should ==  survey
    end

    it "saves the id of the user taking the response" do
      session[:user_id] = 1234
      post :create, :survey_id => survey.id
      Response.find_by_survey_id(survey.id).user_id.should == 1234
    end

    it "redirects to the edit path" do
      post :create, :survey_id => survey.id
      response.should redirect_to edit_survey_response_path(:id => Response.find_by_survey_id(survey.id).id)
    end

    it "redirects to the root path with a flash message when the survey has expired" do
      survey.update_attribute(:expiry_date, 5.days.ago)
      post :create, :survey_id => survey.id
      response.should redirect_to surveys_path
      flash[:error].should_not be_nil
    end

    it "creates blank answers for each of its survey's questions" do
      survey = FactoryGirl.create(:survey, :finalized, :organization_id => 1)
      question = FactoryGirl.create :question, :finalized, :survey => survey
      post :create, :survey_id => survey.id
      question.answers.should_not be_blank
    end

    it "creates blank answers for each of its survey's questions nested under a category" do
      survey = FactoryGirl.create(:survey, :finalized, :organization_id => 1)
      category = FactoryGirl.create :category, :survey => survey
      question = FactoryGirl.create :question, :finalized, :survey => survey, :category => category
      post :create, :survey_id => survey.id
      question.answers.should_not be_blank
    end

    it "creates blank answers for each of its survey's questions nested under a question with options" do
      survey = FactoryGirl.create(:survey, :finalized, :organization_id => 1)
      question = FactoryGirl.create(:radio_question, :with_options, :finalized, :survey => survey)
      sub_question = FactoryGirl.create :question, :finalized, :survey => survey, :parent => question.options[0]
      post :create, :survey_id => survey.id
      sub_question.answers.should_not be_blank
    end
  end

  context "GET 'index'" do
    before(:each) do
      session[:access_token] = "123"
      response = mock(OAuth2::Response)
      access_token = mock(OAuth2::AccessToken)
      names_response = mock(OAuth2::Response)
      organizations_response = mock(OAuth2::Response)
      controller.stub(:access_token).and_return(access_token)

      access_token.stub(:get).with('/api/users/names_for_ids', :params => {:user_ids => [1].to_json}).and_return(names_response)
      access_token.stub(:get).with('/api/organizations').and_return(organizations_response)
      names_response.stub(:parsed).and_return([{"id" => 1, "name" => "Bob"}, {"id" => 2, "name" => "John"}])
      organizations_response.stub(:parsed).and_return([{"id" => 1, "name" => "Foo"}, {"id" => 2, "name" => "Bar"}])
    end

    it "renders the list of responses for a survey if a cso admin is signed in" do
      survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
      res = FactoryGirl.create(:response, :survey => survey,
                               :organization_id => 1, :user_id => 1)
      get :index, :survey_id => survey.id
      response.should be_ok
      assigns(:responses).should == Response.find_all_by_survey_id(survey.id)
    end

    it "sorts the responses by created_at, status" do
      survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
      res_1 = FactoryGirl.create(:response, :survey => survey, :status => "complete",
          :organization_id => 1, :user_id => 1, :created_at => Time.now)
      res_2 = FactoryGirl.create(:response, :survey => survey, :status => "incomplete",
          :organization_id => 1, :user_id => 1, :created_at => 10.minutes.ago)
      res_3 = FactoryGirl.create(:response, :survey => survey, :status => "complete",
          :organization_id => 1, :user_id => 1, :created_at => 10.minutes.ago)
      get :index, :survey_id => survey.id
      assigns(:responses).should == [res_1, res_3, res_2]
    end

    it "gets the user names for all the user_ids of the responses " do
      survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
      res = FactoryGirl.create(:response, :survey => survey,
                               :organization_id => 1, :user_id => 1)
      get :index, :survey_id => survey.id
      assigns(:user_names).should == {1 => "Bob", 2 => "John"}
    end

    it "gets the organization names for all the organization_ids of the responses " do
      survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
      res = FactoryGirl.create(:response, :survey => survey,
                               :organization_id => 1, :user_id => 1)
      get :index, :survey_id => survey.id
      assigns(:organization_names)[0].name.should == "Foo"
      assigns(:organization_names)[1].name.should == "Bar"
    end

    it "doesn't include blank responses" do
      survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
      blank_response = FactoryGirl.create(:response, :blank => true, :survey => survey)
      non_blank_response = FactoryGirl.create(:response, :blank => false, :survey => survey)
      get :index, :survey_id => survey.id
      assigns(:responses).should == [non_blank_response]
    end
  end

  context "GET 'generate_excel'" do
    before(:each) do
      session[:access_token] = "123"
      response = mock(OAuth2::Response)
      access_token = mock(OAuth2::AccessToken)
      names_response = mock(OAuth2::Response)
      organizations_response = mock(OAuth2::Response)
      controller.stub(:access_token).and_return(access_token)

      access_token.stub(:get).with('/api/users/names_for_ids', :params => {:user_ids => [1].to_json}).and_return(names_response)
      access_token.stub(:get).with('/api/organizations').and_return(organizations_response)
      names_response.stub(:parsed).and_return([{"id" => 1, "name" => "Bob"}, {"id" => 2, "name" => "John"}])
      organizations_response.stub(:parsed).and_return([{"id" => 1, "name" => "Foo"}, {"id" => 2, "name" => "Bar"}])
    end

    it "assigns only the completed responses" do
      survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
      resp = FactoryGirl.create(:response, :survey => survey, :status => 'complete')
      incomplete_response = FactoryGirl.create(:response, :status => 'incomplete', :survey => survey)
      validating_response = FactoryGirl.create(:response, :status => 'validating', :survey => survey)
      get :generate_excel, :survey_id => survey.id
      response.should be_ok
      assigns(:responses).should == [resp]
    end

    it "creates a delayed job to generate the excel" do
      survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
      response = FactoryGirl.create(:response, :survey => survey, :status => 'complete')
      expect {
        get :generate_excel, :survey_id => survey.id
      }.to change { Delayed::Job.count }.by 1
    end

    it "renders the filename of the excel file as json" do
      survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
      resp = FactoryGirl.create(:response, :survey => survey, :status => 'complete')
      get :generate_excel, :survey_id => survey.id
      response.should be_ok
      JSON.parse(response.body)['excel_path'].should =~ /#{survey.name}/
    end

    it "renders the id of the new delayed job as json" do
      survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
      resp = FactoryGirl.create(:response, :survey => survey, :status => 'complete')
      get :generate_excel, :survey_id => survey.id
      response.should be_ok
      JSON.parse(response.body)['id'].should == Delayed::Job.all.last.id
    end

    it "renders the excel password in the JSON" do
      survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
      resp = FactoryGirl.create(:response, :survey => survey, :status => 'complete')
      get :generate_excel, :survey_id => survey.id
      response.should be_ok
      password = assigns(:data).password
      JSON.parse(response.body)['password'].should == password
    end

    context "when filtering private questions" do
      it "filters the private questions out by default" do
        survey = FactoryGirl.create(:survey, :organization_id => 1)
        private_question = FactoryGirl.create(:question, :survey => survey, :private => true)
        survey.finalize
        resp = FactoryGirl.create(:response, :survey => survey, :status => 'complete')
        get :generate_excel, :survey_id => survey.id
        response.should be_ok
        assigns(:questions).map(&:id).should_not include private_question.id
      end

      it "doesn't filter the private questions out if the parameter is passed in" do
        survey = FactoryGirl.create(:survey, :organization_id => 1)
        private_question = FactoryGirl.create(:question, :survey => survey, :private => true)
        survey.finalize
        resp = FactoryGirl.create(:response, :survey => survey, :status => 'complete')
        get :generate_excel, :survey_id => survey.id, :disable_filtering => "true"
        response.should be_ok
        assigns(:questions).map(&:id).should include private_question.id
      end
    end

    context "when filtering metadata" do
      it "filters the private metadata out by default" do
        survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
        resp = FactoryGirl.create(:response, :survey => survey, :status => 'complete', :ip_address => "0.0.0.0")
        get :generate_excel, :survey_id => survey.id
        response.should be_ok
        assigns(:metadata).for(resp).should_not include resp.location
        assigns(:metadata).for(resp).should_not include "0.0.0.0"
      end

      it "doesn't filter the private questions out if the parameter is passed in" do
        survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
        resp = FactoryGirl.create(:response, :survey => survey, :status => 'complete', :ip_address => "0.0.0.0")
        get :generate_excel, :survey_id => survey.id, :disable_filtering => "true"
        response.should be_ok
        assigns(:metadata).for(resp).should include resp.location
        assigns(:metadata).for(resp).should include "0.0.0.0"
      end
    end

    context "when filtering by date range" do
      it "includes responses created during the specified range" do
        survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
        date_range = (5.days.ago)..(5.days.from_now)
        early_response = Timecop.freeze(7.days.ago) { FactoryGirl.create(:response, :status => 'complete', :survey => survey) }
        late_response = Timecop.freeze(7.days.from_now) { FactoryGirl.create(:response, :status => 'complete', :survey => survey) }
        response = FactoryGirl.create(:response, :status => 'complete', :survey => survey)
        get :generate_excel, :survey_id => survey.id, :date_range => { :from => date_range.first, :to => date_range.last }
        assigns(:responses).should == [response]
      end
    end
  end

  context "GET 'edit'" do
    before(:each) do
      @survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
      @res = FactoryGirl.create(:response, :survey => @survey,
                               :organization_id => 1, :user_id => 2)
    end

    it "renders the edit page" do
      get :edit, :id => @res.id, :survey_id => @survey.id
      response.should be_ok
      response.should render_template('edit')
    end

    it "assigns a survey and response" do
      get :edit, :id => @res.id, :survey_id => @survey.id
      assigns(:response).should == Response.find(@res.id)
      assigns(:survey).should == @survey
    end

    it "assigns disabled as false" do
      get :edit, :id => @res.id, :survey_id => @survey.id
      assigns(:disabled).should be_false
    end

    it "assigns public_response if the page is accessed externally using the public link" do
      session[:user_id] = nil
      survey = FactoryGirl.create(:survey, :finalized => true, :public => true)
      res = FactoryGirl.create(:response, :survey => survey, :session_token => "123")
      session[:session_token] = "123"
      get :edit, :id => res.id, :survey_id => survey.id, :auth_key => survey.auth_key
      response.should be_ok
      assigns(:public_response).should == true
    end
  end

  context "GET 'show'" do
    before(:each) do
      @survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
      @res = FactoryGirl.create(:response, :survey => @survey,
                               :organization_id => 1, :user_id => 2)
    end

    it "renders the edit page" do
      get :show, :id => @res.id, :survey_id => @survey.id
      response.should be_ok
      response.should render_template('edit')
    end

    it "assigns a survey and response" do
      get :show, :id => @res.id, :survey_id => @survey.id
      assigns(:response).should == Response.find(@res.id)
      assigns(:survey).should == @survey
    end

    it "assigns disabled as true" do
      get :show, :id => @res.id, :survey_id => @survey.id
      assigns(:disabled).should be_true
    end
  end

  context "PUT 'update'" do
    before(:each) { request.env["HTTP_REFERER"] = 'http://example.com' }
    it "doesn't run validations on answers that are empty" do
      survey = FactoryGirl.create(:survey, :organization_id => 1)
      survey.finalize
      res = FactoryGirl.create(:response, :survey => survey,
                               :organization_id => 1, :user_id => 2)
      answer_1 = FactoryGirl.create(:answer, :response => res)
      answer_2 = FactoryGirl.create(:answer, :response => res)
      res.answers << answer_1
      res.answers << answer_2

      put :update, :id => res.id, :survey_id => survey.id, :response =>
        { :answers_attributes => { "0" => { :content => "", :id => answer_2.id},
                                   "1" => { :content => "hello", :id => answer_1.id} } }

      answer_1.reload.content.should == "hello"
      flash[:notice].should_not be_nil
    end

    it "updates the response" do
      survey = FactoryGirl.create(:survey, :organization_id => 1)
      survey.finalize
      res = FactoryGirl.create(:response, :survey => survey,
                               :organization_id => 1, :user_id => 2)
      answer = FactoryGirl.create(:answer)
      res.answers << answer

      put :update, :id => res.id, :survey_id => survey.id, :response =>
        { :answers_attributes => { "0" => { :content => "yeah123", :id => answer.id} } }

      Answer.find(answer.id).content.should == "yeah123"
      flash[:notice].should_not be_nil
    end

    it "renders the edit page if the response is saved successfully" do
      request.env["HTTP_REFERER"] = 'http://example.com'
      survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
      res = FactoryGirl.create(:response, :survey => survey)
      put :update, :id => res.id, :survey_id => survey.id
      response.should redirect_to :back
    end

    it "renders edit page in case of any validations error" do
      survey = FactoryGirl.create(:survey, :organization_id => 1)
      question = FactoryGirl.create(:question, :mandatory, :finalized, :survey => survey)
      survey.finalize
      res = FactoryGirl.create(:response, :survey => survey,
                               :organization_id => 1, :user_id => 2, :status => 'validating')
      answer = FactoryGirl.create(:answer, :question => question)
      res.answers << answer
      put :update, :id => res.id, :survey_id => survey.id, :response =>
        { :answers_attributes => { "0" => { :content => "", :id => answer.id} } }

      response.should render_template('edit')
      answer.reload.content.should == "MyText"
      flash[:error].should_not be_empty
    end

    it "marks the response as not blank" do
      survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
      res = FactoryGirl.create(:response, :survey => survey)
      put :update, :id => res.id, :survey_id => survey.id
      res.reload.should_not be_blank
    end

    it "sends an event to mixpanel" do
      survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
      res = FactoryGirl.create(:response, :survey => survey)
      expect do
        put :update, :id => res.id, :survey_id => survey.id
      end.to change { Delayed::Job.where(:queue => "mixpanel").count }.by(1)
    end
  end

  context "PUT 'complete'" do
    let(:resp) { FactoryGirl.create(:response, :survey_id => survey.id, :organization_id => 1, :user_id => 1, :status => 'validating') }

    it "marks the response complete" do
      put :complete, :id => resp.id, :survey_id => resp.survey_id
      resp.reload.should be_complete
    end

    it "redirects to the response index page on success if the survey is not crowd_sourced" do
      put :complete, :id => resp.id, :survey_id => resp.survey_id
      response.should redirect_to(survey_responses_path(resp.survey_id))
    end

    context "when completing a response to public survey" do
      it "redirects to the root_path if no user is logged in" do
        session[:user_id] = nil
        survey = FactoryGirl.create(:survey, :public => true, :finalized => true)
        resp = FactoryGirl.create(:response, :session_token => "123", :survey => survey)
        session[:session_token] = "123"
        put :complete, :id => resp.id, :survey_id => resp.survey_id
        response.should render_template("thank_you")
      end

      it "redirects to the responses index page if a user is logged in" do
        survey = FactoryGirl.create(:survey, :public => true, :finalized => true, :organization_id => 1)
        resp = FactoryGirl.create(:response, :organization_id => 1, :user_id => 1, :survey => survey)
        put :complete, :id => resp.id, :survey_id => resp.survey_id
        response.should redirect_to survey_responses_path(survey.id)
      end
    end

    it "updates the response" do
      survey = FactoryGirl.create(:survey, :organization_id => 1)
      survey.finalize
      res = FactoryGirl.create(:response, :survey => survey,
                               :organization_id => 1, :user_id => 2)
      answer = FactoryGirl.create(:answer)
      res.answers << answer

      put :complete, :id => res.id, :survey_id => survey.id, :response =>
        { :answers_attributes => { "0" => { :content => "yeah123", :id => answer.id} } }

      Answer.find(answer.id).content.should == "yeah123"
      response.should redirect_to survey_responses_path
      flash[:notice].should_not be_nil
    end

    it "sends an event to mixpanel" do
      expect do
        put :complete, :id => resp.id, :survey_id => resp.survey_id
      end.to change { Delayed::Job.where(:queue => "mixpanel").count }.by(1)
    end

    it "marks the response incomplete if save is unsuccessful" do
      survey = FactoryGirl.create(:survey, :organization_id => 1)
      question = FactoryGirl.create(:question, :finalized, :survey => survey, :mandatory => true)
      survey.finalize
      res = FactoryGirl.create(:response, :survey => survey,
                               :organization_id => 1, :user_id => 2)
      answer = FactoryGirl.create(:answer, :question => question)
      res.answers << answer

      put :complete, :id => res.id, :survey_id => survey.id, :response =>
        { :answers_attributes => { "0" => { :content => "", :id => answer.id} } }
      res.reload.should_not be_complete
    end

    it "doesn't mark an already complete response as incomplete when save if unsuccessful" do
      survey = FactoryGirl.create(:survey, :organization_id => 1)
      question = FactoryGirl.create(:question, :finalized, :survey => survey, :mandatory => true)
      survey.finalize
      res = FactoryGirl.create(:response, :survey => survey,
                               :organization_id => 1, :user_id => 2, :status => 'complete')
      answer = FactoryGirl.create(:answer, :question => question)
      res.answers << answer
      put :complete, :id => res.id, :survey_id => survey.id, :response =>
        { :answers_attributes => { "0" => { :content => "", :id => answer.id} } }
      res.reload.should be_complete
    end

    it "marks the response as not blank" do
      survey = FactoryGirl.create(:survey, :finalized => true, :organization_id => 1)
      res = FactoryGirl.create(:response, :survey => survey)
      put :complete, :id => res.id, :survey_id => survey.id
      res.reload.should_not be_blank
    end
  end

  context "DELETE 'destroy'" do
    let!(:survey) { FactoryGirl.create(:survey, :organization_id => 1, :finalized => true) }
    let!(:res) { FactoryGirl.create(:response, :survey => survey, :organization_id => 1, :user_id => 2) }

    it "deletes a response" do
      expect { delete :destroy, :id => res.id, :survey_id => survey.id }.to change { Response.count }.by(-1)
      flash[:notice].should_not be_nil
    end

    it "redirects to the survey index page" do
      delete :destroy, :id => res.id, :survey_id => survey.id
      response.should redirect_to survey_responses_path
    end

    it "sends an event to mixpanel" do
      expect do
        delete :destroy, :id => res.id, :survey_id => survey.id
      end.to change { Delayed::Job.where(:queue => "mixpanel").count }.by(1)
    end
  end
end
