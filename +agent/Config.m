classdef Config
    % CONFIG Central configuration settings for Orion Agent
    % This class provides a single source of truth for all configuration settings
    
    properties (Constant)
        % Debug Settings
        DEBUG_MODE = false           % Master debug mode toggle
        DEBUG_API_CALLS = false;      % Use hardcoded responses instead of LLM API calls
        DEBUG_AUTO_EXECUTE = false;   % Auto-execute tool chains without user confirmation
        
        % API Settings
        MAX_API_CALLS = 30;          % Maximum API calls per session
        MAX_QPM = 3;                 % Maximum queries per minute
        
        % Tool Settings
        MAX_ITERATIONS = 3;          % Maximum iterations in ReAct loop
        
        % Version Information
        VERSION = '0.1.0';           % Current version of Orion Agent
    end
    
    methods (Static)
        function tf = isDebugMode()
            % Returns true if the system is in debug mode
            tf = agent.Config.DEBUG_MODE;
        end
        
        function tf = useDebugAPIResponse()
            % Returns true if API calls should be replaced with hardcoded responses
            tf = agent.Config.DEBUG_MODE && agent.Config.DEBUG_API_CALLS;
        end
        
        function tf = autoExecuteTools()
            % Returns true if tool chains should be automatically executed
            tf = agent.Config.DEBUG_MODE && agent.Config.DEBUG_AUTO_EXECUTE;
        end
        
        function setDebugMode(value)
            % Sets debug mode - this is a placeholder as MATLAB doesn't allow 
            % changing Constant properties at runtime
            warning('Config:ReadOnly', 'Cannot change DEBUG_MODE at runtime. Edit the Config.m file and restart MATLAB.');
        end
    end
end