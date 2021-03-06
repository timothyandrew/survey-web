require 'spec_helper'

describe QuestionWithOptions do
  context 'when creating blank answers' do
    let(:response) { FactoryGirl.create :response }

    it "creates blank answers for each of its sub-questions" do
      question = FactoryGirl.create(:radio_question, :with_options)
      sub_question = FactoryGirl.create :question, :finalized, :parent => question.options[0]
      question.create_blank_answers(:response_id => response.id)
      sub_question.answers.should_not be_blank
    end

    it "creates blank answers for the contents of each of its sub-categories" do
      question = FactoryGirl.create(:radio_question, :with_options)
      sub_category = FactoryGirl.create :category, :parent => question.options[0]
      sub_question = FactoryGirl.create :question, :finalized, :category => sub_category
      question.create_blank_answers(:response_id => response.id)
      sub_question.answers.should_not be_blank
    end
  end


  context "report data" do
    it "returns an empty array if no answers are present" do
      FactoryGirl.create(:radio_question).report_data.should == []
    end

    it "returns an list of option names along with their counts" do
      question = FactoryGirl.create(:radio_question, :finalized)
      option = FactoryGirl.create(:option, :question => question, :content => "Foo")
      5.times do
        response = FactoryGirl.create(:response, :clean, :complete)
        FactoryGirl.create(:answer, :response => response, :question => question, :content => "Foo")
      end
      question.report_data.should == [["Foo", 5]]
    end
  end

  context "when fetching question with its elements in order as json" do
    it "includes itself" do
      question = RadioQuestion.find(FactoryGirl.create(:question_with_options).id)
      json = question.as_json_with_elements_in_order
      %w(type content id parent_id category_id).each do |attr|
        json[attr].should == question[attr]
      end
    end

    it "includes its options" do
      question = RadioQuestion.find(FactoryGirl.create(:question_with_options).id)
      option = FactoryGirl.create(:option, :question_id => question.id)
      json = question.as_json_with_elements_in_order
      json['options'].size.should == question.options.size
    end
  end

  context "when fetching question with its sub_questions in order" do
    it "includes itself" do
      question = RadioQuestion.find(FactoryGirl.create(:question_with_options).id)
      question.questions_in_order.should include question
    end

    it "includes its options" do
      question = RadioQuestion.find(FactoryGirl.create(:question_with_options).id)
      option = FactoryGirl.create(:option, :question_id => question.id)
      sub_question = FactoryGirl.create(:question, :parent => option)
      question.questions_in_order.should include sub_question
    end
  end
end
