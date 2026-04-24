import { application } from "./application"

// Import all controllers
import GamedayController from "./gameday_controller"
import AgentActivityController from "./agent_activity_controller"
import ToastController from "./toast_controller"
import ShellController from "./shell_controller"
import IncidentFilterController from "./incident_filter_controller"

// Register controllers
application.register("gameday", GamedayController)
application.register("agent-activity", AgentActivityController)
application.register("toast", ToastController)
application.register("shell", ShellController)
application.register("incident-filter", IncidentFilterController)
