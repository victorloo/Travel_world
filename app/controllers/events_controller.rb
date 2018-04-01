class EventsController < ApplicationController
  before_action :find_event, except: [:index, :search, :new, :create]
  before_action :authenticate_user!, except: [:index, :show, :search]
  after_action :update_arg_num, only: [:show]

  def index
    @events = Event.where.not(report: true, disable: true).order('favorites_count DESC').limit(5)
  end

  def show
    @infos = Event.includes(schedules: { details: :spot}).find(params[:id])

    @spot = @infos.schedules.first.spots.first

    @replies = @event.replies
    @reply = Reply.new
    #star rating 功能判別是否有reply，算出star總平均並取小數點後兩位
    @arg_num = @replies.blank? ? 0 : @replies.average(:number).round(2)
  end

  def favorite
    current_user.favorites.create!(event: @event)

    respond_to do |format|
      format.html { redirect_back(fallback_location: root_path )}
      format.js
    end
  end

  def unfavorite
    current_user.favorites.where(event: @event).destroy_all

    respond_to do |format|
      format.html { redirect_back(fallback_location: root_path )}
      format.js
    end
  end

  def search
    #get event_type from session if it is blank
    params[:search] ||= session[:search]
    #save event_type to session for future requests
    session[:search] = params[:search]

    @events = Event.order_search_events(params[:search], params[:order]).page(params[:page]).per(10)
    @populars = Event.where.not(report: true).order('arg_nums DESC').limit(5)
  end

  def clone
    @clone = @event.amoeba_dup
    if @clone.save!
      @org_user = EventsOfUser.find_by(event: @event).user
      current_user.events_of_users.create!(event: @clone, org_user: @org_user.id)
    end
    redirect_back(fallback_location: root_path)
  end

  def report
    if @event.report == false
      @event.update_attributes(report: !@event.report)
      flash[:notice] = "已檢舉行程！"
    else
      flash[:alert] = "此行程已被檢舉！"
    end
    redirect_back(fallback_location: root_path)
  end

  # 共享feature
  # def share
  #   @share = EventsOfUser.copy(@event)
  #   @share.update_attributes(user: current_user, creator: false)
  # end

  def new
    @event = Event.new
    @schedules = Schedule.new
  end

  def create
    @event = Event.new(event_params)
    if @event.save
      @event.events_of_users.create!(user: current_user, event: @event)
      @event.days.times do |i|
        @event.schedules.create!(day: i+=1)
      end
      @schedule_first = @event.schedules.find_by(day: "1")
      @schedule_first.update(schedule_first_params)
      @schedule_last = @event.schedules.find_by(day: @event.days)
      @schedule_last.update(schedule_last_params)
      redirect_to schedules_event_url(@event)
    else  
      flash[:alert] = "標題、日期、國家不能空白!!"     
      render :new
    end
  end

  def schedules
    @schedules = @event.schedules.where(event_id: @event)
    @schedule = Array.new
    (@event.days-1).times do |i|    
      @schedule << @schedules.find_by(day: i+=1)
    end
  end

  def schedulep
    @schedules = @event.schedules.where(event_id: @event)
    if  params["schedules"].each do |key, value|
          @schedules.find_by(id: key).update(schedule_params(value))
        end
      redirect_to search_event_schedules_path(@event,@schedules)     
    else
      render :action => :schedules
    end
  end

  private

  def event_params
    params.require(:event).permit(:title, :info, :start_at, :end_at, :country, :district, :days, :privacy)
  end

  def schedule_params(my_params)
    my_params.permit(:day, :airplane_name, :airplane_number, :airplane_terminal, :airplane_time, :stay, :address, :check_in, :check_out, :event_id,  :schedule_value)
  end

  def schedule_first_params
    params.require(:schedule_first).permit(:day, :airplane_name, :airplane_number, :airplane_terminal, :airplane_time, :stay, :address, :check_in, :check_out, :event_id)
  end

  def schedule_last_params
    params.require(:schedule_last).permit(:day, :airplane_name, :airplane_number, :airplane_terminal, :airplane_time, :stay, :address, :check_in, :check_out, :event_id)
  end

  def find_event
    @event = Event.find_by(id: params[:id], disable: false)
  end

  def update_arg_num
    @event.update(arg_nums: @arg_num)
  end

end
