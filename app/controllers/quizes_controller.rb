require 'challenges'
require 'cgi'

class QuizesController < ApplicationController
  
  before_filter :must_be_signed_in
  
  def show
    # check if the challenge is still open
    @challenge_detail = Challenges.find_by_id(current_access_token, params[:id])[0]
    if @challenge_detail["Is_Open__c"].eql?("false")
      flash[:notice] = "Sorry... we are no longer accepting entries for this challenge."
      redirect_to quizleaderboard_path(params[:id])
    end
    
    # if they are not registered for the challenge, then send them back to the challenge page
    redirect_to challenge_path(params[:id]) unless challenge_participation_status[:status].eql?('Registered')
    
    # see this the member has already entered for today
    member_status = QuickQuizes.member_status_today(current_access_token, params[:id], current_user.username)
    if member_status.size > 0
      flash[:notice] = "You have already submitted for today."
      redirect_to quizleaderboard_path(params[:id])
    end
  end
  
  def fetch_question
    if params[:type].downcase.eql?('practice')
      questions = Utils.shared_dbdc_client.query("select Id, Name, Question__c, Type__c from Quick_Quiz_Question__c where Type__c = 'Practice'")
      render :json => { success: true, questionNbr: 1, question: { Name: "QQQ-0000", Question__c: "#{questions[rand(3)]['Question__c']}", Type__c: "Practice", Id: "0" }, message: "Questions successfully served." }
    else
      render :json => QuickQuizes.fetch_question(current_access_token, current_user.username, params[:id], params[:type])
    end
  end

  def answer
    logger.info "[QuizesController]==== QuickQuiz question #{params['question_id']} received in controller"
    # encode the answer -- rails is decoding it automatically
    params['answer'] = "#{CGI.escape(params['answer'])}"
    results = QuickQuizes.save_answer(current_access_token, current_user.username, params) 
    logger.info "[QuizesController]====  QuickQuiz question #{params['question_id']} save results: #{results}"   
    render :nothing => true    
  end

  def winners
    @challenge_detail = Challenges.find_by_id(current_access_token, params[:id])[0]
    @todays_results = QuickQuizes.winners_today(current_access_token, params[:id], 'all');  
    @winners = QuickQuizes.all_winners(current_access_token, params[:id]);
    @days = []
    @winners.each do |record|
      @days.push(record["Quiz_Date__c"]) unless @days.include?(record["Quiz_Date__c"])
    end
    respond_to do |format|
      format.html
      format.json { render :json => @winners }
    end
  end
  
  def results
    @challenge_detail = Challenges.find_by_id(current_access_token, params[:id])[0]
    # see if they have participated for the today
    member_status = QuickQuizes.member_status_today(current_access_token, params[:id], current_user.username)
    if member_status.empty?
      flash[:notice] = "There are no results for you today."
      redirect_to quizleaderboard_path(params[:id])
    else
      @results = member_status[0]
      @answers = QuickQuizes.member_results_today(current_access_token, params[:id], current_user.username)
      @todays_results = QuickQuizes.winners_today(current_access_token, params[:id], 'all');  
    end
  end
  
  def results_by_member
    @challenge_detail = Challenges.find_by_id(current_access_token, params[:id])[0]
    @todays_results = QuickQuizes.winners_today(current_access_token, params[:id], 'all'); 
    results = QuickQuizes.member_results_by_date(current_access_token, params[:id], params[:member], params[:date])
    if results['success'].eql?('true')
      @answers = results['records']
      flash.now[:warning] = "There are no results for #{params[:member]} for this date. Try changing the username or date in the URL." unless @answers.size > 0
    else
      @answers = []
      flash.now[:error] = "#{results['message']}"
    end    
  end
  
  def answer_by_member
    result = QuickQuizes.member_answer(current_access_token, current_user.email, params[:member])
    if !result['records'].empty?
      @incorrect = result['records'][0]['Quick_Quiz_Question__r']['Question__c'].html_safe
      @correct = result['records'][0]['Quick_Quiz_Question__r']['AnswerPrettyPrint__c'].html_safe
      @type = result['records'][0]['Type__c']
      @answer_id = result['records'][0]['Quick_Quiz_Question__r']['Name']
    end
    render :layout => "blank"
  end
  
  def flag_answer
    QuickQuizes.flag_answer(current_access_token, params[:id])
    render :nothing => true 
  end

  def practice
    # check if the challenge is still open
    @challenge_detail = Challenges.find_by_id(current_access_token, params[:id])[0]
    if @challenge_detail["Is_Open__c"].eql?("false")
      flash[:notice] = "Sorry... we are no longer accepting entries for this challenge."
      redirect_to quizleaderboard_path(params[:id])
    end
  end

  def leaderboard
    # get the categories for the challenge
    params[:type] = 'Random' unless !params[:type].nil?
    @challenge_detail = Challenges.find_by_id(current_access_token, params[:id])[0]
    @today = QuickQuizes.winners_today(current_access_token, params[:id], params[:type]);
    @last7days = QuickQuizes.winners_last7days(current_access_token, params[:id], params[:type]);
    @alltime = QuickQuizes.winners_alltime(current_access_token, params[:id], params[:type]);
  end
  
  # if signed in, then send them back to the challenge page
  def must_be_signed_in
    if !signed_in?
      flash[:error] = "You must be signed in to view the requested page."
      redirect_to challenge_path(params[:id])
    end
  end
  
  private
    
    # TODO - THIS NEEDS TO BE REFACTORED AS THIS METHOD IS ALSO IN THE CHALLENGES CONTROLLER -- but hardcoded quiz id
    def challenge_participation_status
      if signed_in?      
        participation = Challenges.participant_status(current_access_token, current_user.username, params[:id])[0]
        if participation.nil?
          status =  {:status => 'Not Registered', :participantId => nil, :has_submission => false}
        else
          status =  {:status => participation["Status__c"], :participantId => participation["Id"], 
            :has_submission => participation["Has_Submission__c"]}
        end
      else 
        status =  nil
      end
    end
  
    def signed_in?
      !current_user.nil?
    end

end
