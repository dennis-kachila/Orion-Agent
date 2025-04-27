classdef ToolBox < handle
    % TOOLBOX Registers and manages callable tools for the Agent
    
    properties (Access = private)
        tools % Container for tool handles
        toolDescriptions % Descriptions of available tools
    end
    
    methods
        function obj = ToolBox()
            % Constructor - register all available tools
            obj.tools = containers.Map();
            obj.toolDescriptions = struct('name', {}, 'description', {}, 'parameters', {});
            
            % Register all available tools
            obj.register();
        end
        
        function register(obj)
            % Register all available tools with their descriptions
            
            % MATLAB/Simulink tools
            obj.registerTool('new_model', @obj.tools.new_model, ...
                'Create a new Simulink model', ...
                struct('modelName', 'string'));
                
            obj.registerTool('add_block_safe', @obj.tools.add_block_safe, ...
                'Add a block to the model with unique name', ...
                struct('modelName', 'string', 'blockType', 'string', 'position', 'array'));
                
            obj.registerTool('connect', @obj.tools.connect, ...
                'Connect two blocks in the model', ...
                struct('modelName', 'string', 'sourcePath', 'string', 'destPath', 'string'));
                
            obj.registerTool('arrange', @obj.tools.arrange, ...
                'Automatically arrange blocks in the model for better layout', ...
                struct('modelName', 'string'));
                
            obj.registerTool('sim_model', @obj.tools.sim_model, ...
                'Simulate the model and return results', ...
                struct('modelName', 'string', 'simTime', 'double'));
                
            obj.registerTool('open_editor', @obj.tools.open_editor, ...
                'Open MATLAB editor with the specified file', ...
                struct('fileName', 'string'));
                
            obj.registerTool('run_code', @obj.tools.run_code, ...
                'Execute arbitrary MATLAB code and return results', ...
                struct('codeStr', 'string'));
                
            obj.registerTool('doc_search', @obj.tools.doc_search, ...
                'Search documentation or find blocks in libraries', ...
                struct('query', 'string'));
        end
        
        function registerTool(obj, name, handle, description, parameters)
            % Register a single tool with the toolbox
            obj.tools(name) = handle;
            
            % Add tool description
            toolDesc = struct('name', name, 'description', description, 'parameters', parameters);
            obj.toolDescriptions(end+1) = toolDesc;
        end
        
        function [result, isDone] = dispatchTool(obj, toolName, args)
            % Dispatch call to the requested tool
            isDone = false;
            
            try
                % Check if tool exists
                if ~obj.tools.isKey(toolName)
                    error('Tool "%s" not found in registered tools', toolName);
                end
                
                % Get tool handle
                toolHandle = obj.tools(toolName);
                
                % Execute tool with arguments
                try
                    % Call tool with provided arguments
                    if isstruct(args)
                        % Convert struct to name-value pair cell array
                        argNames = fieldnames(args);
                        argValues = struct2cell(args);
                        
                        % Interleave names and values
                        nvPairs = cell(1, 2*numel(argNames));
                        nvPairs(1:2:end) = argNames;
                        nvPairs(2:2:end) = argValues;
                        
                        result = toolHandle(nvPairs{:});
                    else
                        % Direct call with args as is
                        result = toolHandle(args);
                    end
                    
                    % Check if this is a terminal action
                    isDone = false; % By default, continue the loop
                    
                    % Add logic to determine if this is a terminal action
                    % For example, if the action was to present final results to the user
                    if strcmp(toolName, 'present_results')
                        isDone = true;
                    end
                    
                catch ME
                    % Handle tool execution errors
                    errorMsg = obj.simpleRedactErrors(ME);
                    result = struct('error', errorMsg);
                end
            catch ME
                % Handle errors in tool dispatch
                errorMsg = obj.simpleRedactErrors(ME);
                result = struct('error', errorMsg);
            end
        end
        
        function errorMsg = simpleRedactErrors(~, ME)
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
        
        function descriptions = getToolDescriptions(obj)
            % Return descriptions of all registered tools
            descriptions = obj.toolDescriptions;
        end
        
        function toolNames = getToolNames(obj)
            % Return names of all registered tools
            toolNames = keys(obj.tools);
        end
    end
end
