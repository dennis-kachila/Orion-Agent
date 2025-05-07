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
            
            % MATLAB tools
            obj.registerTool('run_code_file', @obj.tools.matlab.run_code_file, ...
                'Execute a MATLAB file and return results', ...
                struct('fileName', 'string'));
            
            obj.registerTool('check_code_lint', @obj.tools.matlab.check_code_lint, ...
                'Check MATLAB code for linting issues', ...
                struct('codeStr', 'string'));
                
            obj.registerTool('open_or_create_file', @obj.tools.matlab.open_or_create_file, ...
                'Open or create a file in MATLAB editor', ...
                struct('fileName', 'string', 'content', 'string'));
                
            obj.registerTool('read_file_content', @obj.tools.matlab.read_file_content, ...
                'Read content from a file', ...
                struct('filePath', 'string'));
                
            obj.registerTool('write_file_contents', @obj.tools.matlab.write_file_contents, ...
                'Write content to a file', ...
                struct('filePath', 'string', 'content', 'string'));
                
            obj.registerTool('get_workspace_var', @obj.tools.matlab.get_workspace_var, ...
                'Get a variable from MATLAB workspace', ...
                struct('varName', 'string'));
                
            obj.registerTool('set_workspace_var', @obj.tools.matlab.set_workspace_var, ...
                'Set a variable in MATLAB workspace', ...
                struct('varName', 'string', 'value', 'any'));
                
            obj.registerTool('run_unit_tests', @obj.tools.matlab.run_unit_tests, ...
                'Run MATLAB unit tests', ...
                struct('testPath', 'string'));
                
            obj.registerTool('commit_git_repo', @obj.tools.matlab.commit_git_repo, ...
                'Commit changes to Git repository', ...
                struct('message', 'string', 'repoPath', 'string'));
            
            % Simulink tools
            obj.registerTool('create_new_model', @obj.tools.simulink.create_new_model, ...
                'Create a new Simulink model', ...
                struct('modelName', 'string'));
                
            obj.registerTool('open_existing_model', @obj.tools.simulink.open_existing_model, ...
                'Open an existing Simulink model', ...
                struct('modelName', 'string'));
                
            obj.registerTool('close_current_model', @obj.tools.simulink.close_current_model, ...
                'Close the current Simulink model', ...
                struct('modelName', 'string', 'saveChanges', 'logical'));
                
            obj.registerTool('save_current_model', @obj.tools.simulink.save_current_model, ...
                'Save the current Simulink model', ...
                struct('modelName', 'string'));
                
            obj.registerTool('insert_library_block', @obj.tools.simulink.insert_library_block, ...
                'Add a block from library to model', ...
                struct('modelName', 'string', 'blockType', 'string', 'position', 'array'));
                
            obj.registerTool('remove_block', @obj.tools.simulink.remove_block, ...
                'Remove a block from the model', ...
                struct('modelName', 'string', 'blockPath', 'string'));
                
            obj.registerTool('connect_block_ports', @obj.tools.simulink.connect_block_ports, ...
                'Connect two blocks in the model', ...
                struct('modelName', 'string', 'sourceBlockPath', 'string', 'destBlockPath', 'string'));
                
            obj.registerTool('disconnect_block_ports', @obj.tools.simulink.disconnect_block_ports, ...
                'Disconnect blocks in the model', ...
                struct('modelName', 'string', 'blockPath', 'string', 'portNumber', 'double'));
                
            obj.registerTool('get_block_params', @obj.tools.simulink.get_block_params, ...
                'Get parameters of a Simulink block', ...
                struct('modelName', 'string', 'blockPath', 'string'));
                
            obj.registerTool('set_block_params', @obj.tools.simulink.set_block_params, ...
                'Set parameters of a Simulink block', ...
                struct('modelName', 'string', 'blockPath', 'string', 'params', 'struct'));
                
            obj.registerTool('auto_layout', @obj.tools.simulink.auto_layout, ...
                'Automatically arrange blocks in the model for better layout', ...
                struct('modelName', 'string'));
                
            obj.registerTool('simulate_model', @obj.tools.simulink.simulate_model, ...
                'Simulate the model and return results', ...
                struct('modelName', 'string', 'simTime', 'double'));
                
            % General tools
            obj.registerTool('doc_search', @obj.tools.general.doc_search, ...
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
                    errorMsg = obj.redactErrorsLocal(ME);
                    result = struct('error', errorMsg);
                end
            catch ME
                % Handle errors in tool dispatch
                errorMsg = obj.redactErrorsLocal(ME);
                result = struct('error', errorMsg);
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
    
    methods (Access = private)
        function errorMsg = redactErrorsLocal(~, ME)
            % Local implementation of error redaction
            msg = ME.message;
            % Remove absolute Windows paths
            msg = regexprep(msg, '[A-Za-z]:\\[^\s\n]*', '[REDACTED_PATH]');
            % Remove OneDrive or user directory references
            msg = regexprep(msg, 'OneDrive[^\s\n]*', '[REDACTED_ONEDRIVE]');
            msg = regexprep(msg, 'Users\\[^\s\n]*', '[REDACTED_USER]');
            % Create error message with basic stack info
            errorMsg = sprintf('Error: %s', msg);
            if ~isempty(ME.stack)
                errorMsg = sprintf('%s\nIn %s at line %d', errorMsg, ME.stack(1).name, ME.stack(1).line);
            end
        end
    end
end
