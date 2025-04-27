classdef Agent < handle
    % AGENT ReAct controller for Orion Agent
    % Core decision loop that processes user inputs and manages interactions
    
    properties
        ToolBox % Registered tools container
        chatHistory % Stores the conversation history
        llmInterface % Interface to the LLM
    end
    
    methods
        function obj = Agent()
            % Constructor - initialize the agent components
            obj.ToolBox = agent.ToolBox();
            obj.chatHistory = struct('role', {}, 'content', {});
            obj.llmInterface = @llm.callGPT;
            
            % Add system message to history
            systemPrompt = llm.promptTemplates.getSystemPrompt();
            obj.chatHistory(end+1) = struct('role', 'system', 'content', systemPrompt);
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
                    
                    % Dispatch to appropriate tool
                    [result, isDone] = obj.ToolBox.dispatchTool(toolCall.tool, toolCall.args);
                    
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
                        response = resultStr;
                        break;
                    end
                    
                catch ME
                    % Handle errors
                    errorMsg = agent.utils.redactErrors(ME);
                    obj.chatHistory(end+1) = struct('role', 'system', 'content', ...
                        sprintf('Error: %s', errorMsg));
                    
                    % Update prompt with error
                    fullPrompt = llm.promptTemplates.buildPrompt(obj.chatHistory, obj.ToolBox.getToolDescriptions());
                end
            end
            
            % If no response generated within max iterations
            if isempty(response)
                response = 'Max iterations reached without completing the task.';
            end
            
            return;
        end
        
        function history = getHistory(obj)
            % Return current conversation history
            history = obj.chatHistory;
        end
        
        function clearHistory(obj)
            % Clear conversation history except system prompt
            systemPrompt = obj.chatHistory(1);
            obj.chatHistory = systemPrompt;
        end
    end
end
