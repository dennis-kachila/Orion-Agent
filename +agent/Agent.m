classdef Agent < handle
    % AGENT ReAct controller for Orion Agent
    % Core decision loop that processes user inputs and manages interactions
    
    properties
        ToolBox % Registered tools container
        chatHistory % Stores the conversation history
        llmInterface % Interface to the LLM
        toolLog % Maintains a log of all tool calls made
        modifiedFiles % Tracks files that have been created or modified
    end
    
    methods
        function obj = Agent()
            % Constructor - initialize the agent components
            obj.ToolBox = agent.ToolBox();
            obj.chatHistory = struct('role', {}, 'content', {});
            obj.llmInterface = @llm.callGPT;
            obj.toolLog = {};
            obj.modifiedFiles = {};
            
            % Add system message to history
            try
                % Use fully qualified path to avoid namespace issues
                systemPrompt = llm.promptTemplates.getSystemPrompt();
                obj.chatHistory(end+1) = struct('role', 'system', 'content', systemPrompt);
            catch ME
                warning(ME.identifier, '%s', ME.message);
                % Use a simple default prompt if the system prompt can't be loaded
                obj.chatHistory(end+1) = struct('role', 'system', 'content', 'You are Orion, an AI assistant for MATLAB and Simulink.');
            end
        end
        
        function response = processUserInput(obj, userText)
            % Process user input and return agent response
            % Add user message to history
            obj.chatHistory(end+1) = struct('role', 'user', 'content', userText);
            
            % Generate prompt with history and tool descriptions
            fullPrompt = llm.promptTemplates.buildPrompt(obj.chatHistory, obj.ToolBox.getToolDescriptions());
            
            % Execute ReAct loop until completion or max iterations
            maxIterations = 10;
            iterCount = 0;
            
            response = '';
            
            % Clear tool log and file list for new user request
            obj.toolLog = {};
            obj.modifiedFiles = {};
            
            while iterCount < maxIterations
                iterCount = iterCount + 1;
                
                % Call LLM to determine next action
                try
                    llmResponse = obj.llmInterface(fullPrompt);
                    
                    % Parse JSON response to get tool and args
                    toolCall = jsondecode(llmResponse);
                    
                    if ~isfield(toolCall, 'tool') || ~isfield(toolCall, 'args')
                        error('Invalid LLM response format. Expected fields "tool" and "args".');
                    end
                    
                    % Record thought in history
                    thought = sprintf('I will use %s with arguments: %s', ...
                        toolCall.tool, jsonencode(toolCall.args));
                    obj.chatHistory(end+1) = struct('role', 'assistant', 'content', thought);
                    
                    % Add to tool log
                    obj.toolLog{end+1} = sprintf('%s(%s)', toolCall.tool, jsonencode(toolCall.args));
                    
                    % Dispatch to appropriate tool
                    [result, isDone] = obj.ToolBox.dispatchTool(toolCall.tool, toolCall.args);
                    
                    % Check for file creation/modification
                    if isfield(result, 'fileName')
                        % For tools like open_editor that create/modify files
                        if ~ismember(result.fileName, obj.modifiedFiles)
                            obj.modifiedFiles{end+1} = result.fileName;
                        end
                    elseif isfield(result, 'modelName')
                        % For Simulink model files
                        modelFile = [result.modelName, '.slx'];
                        if ~ismember(modelFile, obj.modifiedFiles)
                            obj.modifiedFiles{end+1} = modelFile;
                        end
                    end
                    
                    % Record observation in history
                    if isstruct(result) || iscell(result)
                        resultStr = jsonencode(result);
                    elseif ischar(result) || isstring(result)
                        resultStr = char(result);
                    else
                        resultStr = 'Result cannot be displayed in text form';
                    end
                    
                    obj.chatHistory(end+1) = struct('role', 'system', 'content', resultStr);
                    
                    % Update full prompt with new history
                    fullPrompt = llm.promptTemplates.buildPrompt(obj.chatHistory, obj.ToolBox.getToolDescriptions());
                    
                    % If task complete, return final response
                    if isDone
                        % Create complete response with all required fields
                        finalResponse = struct(...
                            'summary', 'Task completed successfully', ...
                            'files', {obj.modifiedFiles}, ...
                            'log', {obj.toolLog}, ...
                            'snapshot', '');
                        
                        % Add snapshot if available
                        if isfield(result, 'snapshot') && ~isempty(result.snapshot)
                            finalResponse.snapshot = ['data:image/png;base64,', result.snapshot];
                        end
                        
                        % Convert to JSON
                        response = jsonencode(finalResponse);
                        break;
                    end
                    
                catch ME
                    % Handle errors using direct error handling instead of agent.utils.safeRedactErrors
                    errorMsg = obj.simpleRedactErrors(ME);
                    obj.chatHistory(end+1) = struct('role', 'system', 'content', ...
                        sprintf('Error: %s', errorMsg));
                    
                    % Update prompt with error
                    fullPrompt = llm.promptTemplates.buildPrompt(obj.chatHistory, obj.ToolBox.getToolDescriptions());
                end
            end
            
            % If no response generated within max iterations
            if isempty(response)
                % Create error response with required fields
                errorResponse = struct(...
                    'summary', 'Max iterations reached without completing the task', ...
                    'files', {obj.modifiedFiles}, ...
                    'log', {obj.toolLog}, ...
                    'error', 'Could not complete task within maximum iterations');
                
                response = jsonencode(errorResponse);
            end
            
            return;
        end
        
        function errorMsg = simpleRedactErrors(obj, ME)
            % SIMPLEREDACTERRORS - Basic error redacting function
            % This function replaces the dependency on agent.utils.safeRedactErrors
            % with a direct implementation to avoid namespace issues
            
            try
                % Get the error message
                errorMsg = ME.message;
                
                % Remove file paths
                errorMsg = regexprep(errorMsg, 'File: [^\n]*', 'File: [REDACTED]');
                
                % Remove any absolute paths that might be in the message
                errorMsg = regexprep(errorMsg, '([A-Za-z]:\\[^:"\s\n\r]+)', '[REDACTED_PATH]');
                errorMsg = regexprep(errorMsg, '(/[^:"\s\n\r]+)', '[REDACTED_PATH]');
                
                % Limit stack trace
                if ~isempty(ME.stack)
                    % Include only the function name and line number for the first few stack frames
                    stackStr = '\nStack trace (limited):\n';
                    
                    maxStackFrames = min(3, length(ME.stack));
                    for i = 1:maxStackFrames
                        frame = ME.stack(i);
                        % Only include function name and line, not full file path
                        stackStr = [stackStr, sprintf('  - Function: %s, Line: %d\n', ...
                            frame.name, frame.line)];
                    end
                    
                    errorMsg = [errorMsg, stackStr];
                end
            catch InnerME
                % If error handling fails, return a simple error message
                errorMsg = sprintf('Error: %s', ME.message);
            end
        end
        
        function history = getHistory(obj)
            % Return current conversation history
            history = obj.chatHistory;
        end
        
        function clearHistory(obj)
            % Clear conversation history except system prompt
            systemPrompt = obj.chatHistory(1);
            obj.chatHistory = systemPrompt;
            obj.toolLog = {};
            obj.modifiedFiles = {};
        end
        
        function log = getToolLog(obj)
            % Get the log of tool calls made
            log = obj.toolLog;
        end
        
        function files = getModifiedFiles(obj)
            % Get the list of files that were created or modified
            files = obj.modifiedFiles;
        end
    end
end
