import { application } from "./application"

// Import all controllers
import GamedayController from "./gameday_controller"
import AgentActivityController from "./agent_activity_controller"
import ToastController from "./toast_controller"
import ShellController from "./shell_controller"
import IncidentFilterController from "./incident_filter_controller"
import CommandBarController from "./command_bar_controller"
import DemoFlowController from "./demo_flow_controller"
import IncidentActionsController from "./incident_actions_controller"
import OverrideModalController from "./override_modal_controller"

// Register controllers
application.register("gameday", GamedayController)
application.register("agent-activity", AgentActivityController)
application.register("toast", ToastController)
application.register("shell", ShellController)
application.register("incident-filter", IncidentFilterController)
application.register("command-bar", CommandBarController)
application.register("demo-flow", DemoFlowController)
application.register("incident-actions", IncidentActionsController)
application.register("override-modal", OverrideModalController)
