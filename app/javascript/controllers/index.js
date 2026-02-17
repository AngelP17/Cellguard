import { application } from "./application"

// Import all controllers
import GamedayController from "./gameday_controller"
import AgentActivityController from "./agent_activity_controller"

// Register controllers
application.register("gameday", GamedayController)
application.register("agent-activity", AgentActivityController)
