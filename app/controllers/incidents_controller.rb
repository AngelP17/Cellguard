class IncidentsController < ApplicationController
  def index
    @incidents = Incident.order(created_at: :desc).limit(50)
  end
end
