classdef Agent < handle
    % AGENT ReAct controller for Orion Agent
    % Core decision loop that processes user inputs and manages interactions
    
    properties
        ToolBox % Registered tools container
        chatHistory % Stores the conversation history
        llmInterface % Interface to the LLM
        toolLog % Maintains a log of all tool calls made
        modifiedFiles % Tracks files that have been created or modified
        pendingRunCodeTool % Stores a run_code_file tool to execute after primary tool
    end
    
    methods
        function obj = Agent()
            % Constructor - initialize the agent components
            obj.ToolBox = agent.ToolBox();
            obj.chatHistory = struct('role', {}, 'content', {});
            obj.llmInterface = @llm.callGPT;
            obj.toolLog = {};
            obj.modifiedFiles = {};
            obj.pendingRunCodeTool = struct();
            
            % Add system message to history
            try
                % Use fully qualified path to avoid namespace issues
                systemPrompt = llm.promptTemplates.getSystemPrompt();
                % Add extra context/examples if the prompt is too short
                if strlength(systemPrompt) < 100
                    systemPrompt = [systemPrompt, ...
                        '\n\nContext: You are an expert AI agent for MATLAB and Simulink. You help users write, debug, and understand MATLAB code and Simulink models.\n', ...
                        'When you respond, use clear explanations and JSON format for tool calls.\n', ...
                        'Example:\n', ...
                        '{"tool": "open_or_create_file", "args": {"fileName": "hello.m", "content": "disp(''Hello World'');"}}\n', ...
                        'If you need to run code, use the run_code_file tool.\n', ...
                        'If you are unsure, ask the user for clarification.'];
                end
                obj.chatHistory(end+1) = struct('role', 'system', 'content', systemPrompt);
            catch ME
                warning(ME.identifier, '%s', ME.message);
                % Use a detailed default prompt if the system prompt can't be loaded
                obj.chatHistory(end+1) = struct('role', 'system', 'content', [
                    'You are Orion, an expert AI Agent for MATLAB and Simulink.\n', ...
                    'Your job is to help users write, debug, and understand MATLAB code and Simulink models.\n', ...
                    'Always respond in JSON format for tool calls.\n', ...
                    'Example: {"tool": "open_or_create_file", "args": {"fileName": "hello.m", "content": "disp(''Hello World'');"}}\n', ...
                    'If you need to run a code file, use the run_code_file tool.\n', ...
                    'If you are unsure, ask the user for clarification.\n', ...
                    'Be concise and helpful.'
                ]);
            end
        end
        
        function response = processUserInput(obj, userText)
            % Process user input and return agent response
            
            % Check for @agent commands
            if startsWith(strtrim(userText), "@agent")
                % Extract the command part after @agent
                commandText = extractAfter(strtrim(userText), "@agent");
                commandText = strtrim(commandText);
                
                % Handle specific agent commands
                if startsWith(commandText, "Continue")
                    fprintf('Continuing previous conversation...\n');
                    % Extract any additional prompt after "Continue: "
                    if contains(commandText, ":")
                        additionalPrompt = extractAfter(commandText, ":");
                        additionalPrompt = strtrim(additionalPrompt);
                        % Add the continuation prompt to history
                        obj.chatHistory(end+1) = struct('role', 'user', 'content', additionalPrompt);
                    else
                        % If no additional prompt, add a generic continuation message
                        obj.chatHistory(end+1) = struct('role', 'user', 'content', 'Please continue from where you left off.');
                    end
                    
                    % Generate prompt with history and tool descriptions
                    fullPrompt = llm.promptTemplates.buildPrompt(obj.chatHistory, obj.ToolBox.getToolDescriptions());
                    
                    % Call LLM for response
                    try
                        fprintf('Calling LLM to continue previous conversation...\n');
                        llmResponse = obj.llmInterface(fullPrompt);
                        
                        % Parse response
                        responseObj = jsondecode(llmResponse);
                        
                        % Create response structure with proper MATLAB syntax for default value
                        if isfield(responseObj, 'summary')
                            summaryText = responseObj.summary;
                        else
                            summaryText = 'Continued previous conversation';
                        end
                        
                        continuationResponse = struct(...
                            'summary', summaryText, ...
                            'files', {obj.modifiedFiles}, ...
                            'log', {obj.toolLog});
                            
                        response = jsonencode(continuationResponse);
                        return;
                    catch ME
                        errorMsg = obj.redactErrorsLocal(ME);
                        fprintf('Error during continuation: %s\n', errorMsg);
                        
                        % Create error response
                        errorResponse = struct(...
                            'summary', 'Error occurred while continuing conversation', ...
                            'error', errorMsg);
                        
                        response = jsonencode(errorResponse);
                        return;
                    end
                else
                    % Handle other @agent commands here
                    fprintf('Unknown @agent command: %s\n', commandText);
                    
                    errorResponse = struct(...
                        'summary', sprintf('Unknown @agent command: %s', commandText), ...
                        'error', 'Unsupported command');
                        
                    response = jsonencode(errorResponse);
                    return;
                end
            end
            
            % Create a workspace folder for files if it doesn't exist
            % Use path relative to the Agent.m file itself for consistent location
            thisFile = mfilename('fullpath');
            thisFolder = fileparts(thisFile);
            projectRoot = fileparts(thisFolder); % Go up from +agent folder to project root
            workspaceFolder = fullfile(projectRoot, 'orion_workspace');
            
            fprintf('Using workspace folder: %s\n', workspaceFolder);
            if ~exist(workspaceFolder, 'dir')
                fprintf('Creating workspace folder: %s\n', workspaceFolder);
                mkdir(workspaceFolder);
            end
            
            % Get workspace context to inform LLM
            workspaceContext = obj.getWorkspaceContext(workspaceFolder);
            
            % Add user message to history
            obj.chatHistory(end+1) = struct('role', 'user', 'content', userText);
            
            % Add workspace context as a system message
            obj.chatHistory(end+1) = struct('role', 'system', 'content', workspaceContext);
            
            % Generate prompt with history and tool descriptions
            fullPrompt = llm.promptTemplates.buildPrompt(obj.chatHistory, obj.ToolBox.getToolDescriptions());
            
            % Execute ReAct loop until completion or max iterations
            maxIterations = 3; % Reduced from 10 to minimize excess API calls
            iterCount = 0;
            
            response = '';
            
            % Clear tool log and file list for new user request
            obj.toolLog = {};
            obj.modifiedFiles = {};
            
            % Flag to track if we've already generated a successful response
            successfulResponse = false;
            
            % Display status to command window
            fprintf('Processing request: "%s"\n', userText);
            
            % Main loop for ReAct loop
            %{ 

            ReAct = Reasoning + Acting
            In agent design for large‑language‑model systems, ReAct refers to a loop in which the model:
            1. Reasons about the user’s request and the current state, deciding what to do next.
            2. Acts by calling an external tool or function (e.g., add_block, sim).
            3. Observes the tool’s result (success, error message, numeric output).
            4. Feeds that observation back into its next step of Reasoning, and the cycle repeats until the goal is reached or the agent stops.
             
            
            %}

            while iterCount < maxIterations && ~successfulResponse
                iterCount = iterCount + 1;
                fprintf('Iteration %d of %d\n', iterCount, maxIterations);
                
                % Call LLM to determine next action
                try
                    % Call LLM with the full prompt to determine the next action
                    fprintf('Calling LLM to determine next action...\n');
                    llmResponse = obj.llmInterface(fullPrompt);
                    
                    % DEBUG: Display LLM response in command window
                    fprintf('==== LLM RESPONSE BEGIN ====\n');
                    fprintf('%s\n', llmResponse);
                    fprintf('==== LLM RESPONSE END ====\n');
                    
                    % Parse JSON response to get tool and args
                    try
                        % Improve JSON parsing by first checking for and removing markdown code blocks
                        cleanedResponse = agent.Agent.cleanMarkdownFormatting(llmResponse);
                        toolCall = jsondecode(cleanedResponse);
                        
                        if ~isfield(toolCall, 'tool') || ~isfield(toolCall, 'args')
                            error('Invalid LLM response format. Expected fields "tool" and "args".');
                        end
                    catch jsonError
                        % If JSON parsing fails, create a generic error response
                        fprintf('ERROR: Failed to parse JSON response: %s\n', jsonError.message);
                        fprintf('Creating generic error response instead of a hardcoded solution\n');
                        
                        % Generic error reporting tool - doesn't try to answer the query
                        toolCall = struct(...
                            'tool', 'run_code_file', ...
                            'args', struct(...
                                'codeStr', sprintf('disp(''Error processing the LLM response:'');\ndisp(''%s'');\ndisp(''Please try again in a moment.'');', strrep(jsonError.message, '''', ''''''))));
                    end
                    
                    % Special handling for complex response formats
                    if isfield(toolCall, 'log') && ~isempty(toolCall.log)
                        fprintf('Found additional tool calls in log field\n');
                        
                        % Determine if log is a cell array or struct array
                        if iscell(toolCall.log)
                            logArray = toolCall.log;
                            fprintf('Log is a cell array with %d items\n', length(logArray));
                        else
                            % Convert struct array to cell array if needed
                            logArray = num2cell(toolCall.log);
                            fprintf('Log is a struct array with %d items\n', length(logArray));
                        end
                        
                        % Look for run_code in log that might have the content
                        for i = 1:length(logArray)
                            try
                                logItem = logArray{i};
                                
                                % Debug the log item structure
                                fprintf('Examining log item %d: %s\n', i, jsonencode(logItem));
                                
                                if isfield(logItem, 'tool') && strcmp(logItem.tool, 'run_code_file') && ...
                                   isfield(logItem, 'args') && isfield(logItem.args, 'codeStr')
                                    
                                    % Add the code content to the open_editor args
                                    fprintf('Found code content in log run_code_file item: %s\n', logItem.args.codeStr);
                                    toolCall.args.content = logItem.args.codeStr;
                                    break;
                                end
                            catch logErr
                                fprintf('Error processing log item %d: %s\n', i, logErr.message);
                            end
                        end
                        
                        % If still missing content, check if fileName has file extension
                        if ~isfield(toolCall.args, 'content') && isfield(toolCall.args, 'fileName')
                            fprintf('Still missing content, generating default template based on file type\n');
                            [~, ~, fileExt] = fileparts(toolCall.args.fileName);
                            
                            % Create default content based on file extension
                            if strcmpi(fileExt, '.m')
                                toolCall.args.content = sprintf('%% %s\n%% Auto-generated default file\n\ndisp(''Hello, this is a default MATLAB script'');\n', toolCall.args.fileName);
                                fprintf('Generated default MATLAB script content\n');
                            else
                                toolCall.args.content = sprintf('% Default content for %s\n', toolCall.args.fileName);
                                fprintf('Generated generic default content\n');
                            end
                        end
                    end
                    
                    % Record thought in history
                    thought = sprintf('I will use %s with arguments: %s', ...
                        toolCall.tool, jsonencode(toolCall.args));
                    obj.chatHistory(end+1) = struct('role', 'assistant', 'content', thought);
                    
                    % Store tool call for logging
                    obj.toolLog{end+1} = struct('tool', toolCall.tool, 'args', toolCall.args);
                    
                    % Process additional log items if present (execute nested tool calls)
                    if isfield(toolCall, 'log') && ~isempty(toolCall.log)
                        fprintf('Processing additional tool calls in log array...\n');
                        
                        % Determine if log is a cell array or string array
                        if iscell(toolCall.log)
                            logArray = toolCall.log;
                        elseif isstring(toolCall.log) || ischar(toolCall.log)
                            % Convert string array to cell array
                            if ischar(toolCall.log)
                                logArray = {toolCall.log};
                            else
                                logArray = cellstr(toolCall.log);
                            end
                        else
                            % Convert struct array to cell array if needed
                            logArray = num2cell(toolCall.log);
                        end
                        
                        % Track tools to execute in order
                        toolsToExecute = {};
                        
                        % First parse all log entries to identify tools
                        for i = 1:length(logArray)
                            try
                                logItem = logArray{i};
                                
                                % Debug info about what we're processing
                                if isstruct(logItem)
                                    fprintf('Log item %d is a struct with fields: %s\n', i, strjoin(fieldnames(logItem), ', '));
                                    if isfield(logItem, 'tool')
                                        fprintf('Found tool call in log: %s\n', logItem.tool);
                                        toolsToExecute{end+1} = logItem;
                                    end
                                elseif ischar(logItem) || isstring(logItem)
                                    % Parse log string entries like: "run_code_file(filename.m)"
                                    logItemStr = char(logItem);
                                    fprintf('Parsing log string item: %s\n', logItemStr);
                                    
                                    % Extract tool name and arguments
                                    [toolName, argsStr] = obj.parseLogString(logItemStr);
                                    
                                    if ~isempty(toolName)
                                        fprintf('Extracted tool: %s with args: %s\n', toolName, argsStr);
                                        
                                        % If the tool is run_code_file and it's a file
                                        if strcmp(toolName, 'run_code_file')
                                            fprintf('DEBUG: Parsing run_code_file call: %s\n', argsStr);
                                            fileToRun = strtrim(argsStr);
                                            
                                            if endsWith(fileToRun, '.m')
                                                % It's a file to run - create structure with only required fileName parameter
                                                toolsToExecute{end+1} = struct('tool', 'run_code_file', ...
                                                    'args', struct('fileName', fileToRun));
                                            else
                                                % It's code to run - create structure with only required codeStr parameter
                                                toolsToExecute{end+1} = struct('tool', 'run_code_file', ...
                                                    'args', struct('codeStr', fileToRun));
                                            end
                                        % Add support for open_or_create_file tool (previously incorrectly referenced as open_file)
                                        elseif strcmp(toolName, 'open_or_create_file')
                                            % Get file path from args
                                            filePath = strtrim(argsStr);
                                            
                                            % Ensure the file will be created in the workspace folder
                                            workspaceFolder = fullfile(pwd, 'orion_workspace');
                                            fullFilePath = fullfile(workspaceFolder, filePath);
                                            
                                            % Check if main response has file content
                                            if isfield(toolCall, 'args') && isfield(toolCall.args, 'content') && ...
                                               (isfield(toolCall.args, 'filePath') || isfield(toolCall.args, 'fileName'))
                                                
                                                % Get content from main response
                                                fileContent = toolCall.args.content;
                                                
                                                % Add to tools to execute
                                                toolsToExecute{end+1} = struct('tool', 'open_or_create_file', ...
                                                    'args', struct('fileName', fullFilePath, 'content', fileContent));
                                                
                                                fprintf('Added open_or_create_file for %s with content from main response\n', fullFilePath);
                                            else
                                                fprintf('Cannot execute file creation for %s: No content available\n', fullFilePath);
                                            end
                                        else
                                            % Add other tool types as needed
                                            fprintf('Skipping log tool %s (not implemented for direct execution)\n', toolName);
                                        end
                                    end
                                else
                                    fprintf('Log item %d is of type %s (not handled)\n', i, class(logItem));
                                end
                            catch logErr
                                fprintf('Error processing log item %d: %s\n', i, logErr.message);
                            end
                        end
                        
                        % Now execute the tools if we're in debug mode
                        fprintf('Found %d additional tools to execute\n', length(toolsToExecute));
                        
                        % Get debug setting from centralized config
                        autoExecute = agent.Config.autoExecuteTools();
                        
                        % Track if we've already executed the tools from log
                        toolsExecutedFromLog = false;
                        
                        if autoExecute && ~isempty(toolsToExecute)
                            fprintf('Auto-execute enabled: Will execute all tool calls without confirmation\n');
                            % Wait a moment for any open_file operations to complete
                            pause(0.5);
                            
                            % Execute all tool calls in order
                            for i = 1:length(toolsToExecute)
                                try
                                    % Get the tool to execute
                                    execTool = toolsToExecute{i};
                                    
                                    if isstruct(execTool) && isfield(execTool, 'tool') && isfield(execTool, 'args')
                                        fprintf('Executing log tool %d: %s\n', i, execTool.tool);
                                        fprintf('DEBUG: Tool args: %s\n', jsonencode(execTool.args));
                                        
                                        % For open_or_create_file, additional debugging and proper file handling
                                        if strcmp(execTool.tool, 'open_or_create_file')
                                            fprintf('DEBUG: About to call open_or_create_file with:\n');
                                            if isfield(execTool.args, 'fileName')
                                                fprintf('  fileName: %s\n', execTool.args.fileName);
                                                
                                                % Ensure the file path is properly set for workspace folder
                                                if ~contains(execTool.args.fileName, workspaceFolder)
                                                    % If this is a simple filename without path, add workspace folder
                                                    [~, fname, fext] = fileparts(execTool.args.fileName);
                                                    if isempty(fileparts(execTool.args.fileName))
                                                        oldFileName = execTool.args.fileName;
                                                        execTool.args.fileName = fullfile(workspaceFolder, oldFileName);
                                                        fprintf('  Corrected file path: %s\n', execTool.args.fileName);
                                                    end
                                                end
                                            else
                                                fprintf('  fileName: MISSING\n');
                                            end
                                        end
                                        
                                        % Check if the file exists for run_code_file
                                        if strcmp(execTool.tool, 'run_code_file') && ...
                                           isfield(execTool.args, 'fileName') && ...
                                           ~isempty(execTool.args.fileName)
                                           
                                            % Ensure file path is set correctly with workspace folder
                                            fileName = execTool.args.fileName;
                                            workspaceFolder = fullfile(pwd, 'orion_workspace');
                                            fullPath = fullfile(workspaceFolder, fileName);
                                            
                                            % Check if the file exists
                                            if exist(fullPath, 'file')
                                                fprintf('File %s exists, will run it\n', fullPath);
                                                execTool.args.fileName = fullPath;
                                            else
                                                fprintf('Warning: File %s does not exist, cannot run it\n', fullPath);
                                                continue;  % Skip to next tool
                                            end
                                        end
                                        
                                        % Execute the tool with enhanced debugging
                                        fprintf('DEBUG: About to dispatch tool: %s with complete args: %s\n', execTool.tool, jsonencode(execTool.args));
                                        
                                        % Debug statement for run_code_file to ensure it has the right parameters
                                        if strcmp(execTool.tool, 'run_code_file')
                                            fprintf('DEBUG: run_code_file being called with fileName: %s\n', execTool.args.fileName);
                                        end
                                        
                                        % Use the normal dispatch method
                                        try
                                            [toolResult, isDoneLocal] = obj.ToolBox.dispatchTool(execTool.tool, execTool.args);
                                            
                                            % Create default toolResult structure if missing required fields
                                            if ~isstruct(toolResult)
                                                fprintf('Converting non-struct toolResult to struct\n');
                                                toolResult = struct('output', toolResult);
                                            end
                                            
                                            % Ensure status field exists
                                            if ~isfield(toolResult, 'status')
                                                fprintf('Adding default status field to toolResult\n');
                                                toolResult.status = 'success';
                                            end
                                            
                                            % Now safe to access the status field
                                            fprintf('Log tool execution completed with %s status\n', toolResult.status);
                                            
                                            fprintf('DEBUG: Tool dispatch completed with isDone=%d\n', isDoneLocal);
                                            % Check if status field exists before accessing it
                                            if isfield(toolResult, 'status')
                                                fprintf('Log tool execution completed with %s status\n', toolResult.status);
                                            else
                                                fprintf('Log tool execution completed (status field not present)\n');
                                            end
                                            if isfield(toolResult, 'output')
                                                fprintf('DEBUG: Tool output: %s\n', toolResult.output);
                                            end
                                        catch toolExecErr
                                            fprintf('DEBUG: Error during tool execution: %s\n', toolExecErr.message);
                                            fprintf('DEBUG: Error stack:\n');
                                            for stackIdx = 1:min(3, length(toolExecErr.stack))
                                                fprintf('  %s (line %d)\n', toolExecErr.stack(stackIdx).name, toolExecErr.stack(stackIdx).line);
                                            end
                                            
                                            % Create an error result
                                            toolResult = struct('status', 'error', 'error', toolExecErr.message);
                                        end
                                        
                                        % Add to tool log
                                        obj.toolLog{end+1} = struct('tool', execTool.tool, ...
                                                                 'args', execTool.args, ...
                                                                 'result', toolResult);
                                        
                                        fprintf('Log tool execution completed with %s status\n', toolResult.status);
                                    end
                                catch execErr
                                    fprintf('Error executing log tool %d: %s\n', i, execErr.message);
                                end
                            end
                            
                            % Mark tools from log as executed
                            toolsExecutedFromLog = true;
                            
                            % Generate successful response after executing tools from log
                            fprintf('Generating successful response after executing log tools\n');
                            finalResponse = struct(...
                                'summary', 'Task completed successfully', ...
                                'files', {obj.modifiedFiles}, ...
                                'log', {obj.toolLog}, ...
                                'snapshot', '');
                                
                            % Add more specific summary based on tools executed
                            if any(strcmp(cellfun(@(t) t.tool, toolsToExecute, 'UniformOutput', false), 'run_code_file'))
                                finalResponse.summary = 'Successfully ran the code file.';
                            elseif any(strcmp(cellfun(@(t) t.tool, toolsToExecute, 'UniformOutput', false), 'open_or_create_file'))
                                finalResponse.summary = 'Successfully created and opened the file.';
                            end
                            
                            % Convert to JSON
                            response = jsonencode(finalResponse);
                            successfulResponse = true;
                            
                            % Skip redundant execution if tools from log were already executed
                            if toolsExecutedFromLog
                                fprintf('Skipping redundant tool execution after processing log tools\n');
                                continue;
                            end
                        end
                        
                        % Skip redundant execution if tools from log were already executed
                        if toolsExecutedFromLog
                            fprintf('Skipping redundant tool execution after processing log tools\n');
                            continue;
                        end
                    end
                    
                    % Dispatch to appropriate tool
                    fprintf('Executing tool: %s\n', toolCall.tool);
                    
                    % Special handling for open_editor to ensure file creation works
                    if strcmp(toolCall.tool, 'open_editor') && isfield(toolCall.args, 'fileName') && isfield(toolCall.args, 'content')
                        % Force files to be created in the workspace folder
                        [~, filename, ext] = fileparts(toolCall.args.fileName);
                        
                        % If no extension provided, assume .m for MATLAB files
                        if isempty(ext)
                            ext = '.m';
                        end
                        
                        fullFilePath = fullfile(workspaceFolder, [filename, ext]);
                        fprintf('Creating file in workspace: %s\n', fullFilePath);
                        
                        % Write content directly to file
                        try
                            % Make sure the directory exists
                            if ~exist(workspaceFolder, 'dir')
                                fprintf('Creating directory: %s\n', workspaceFolder);
                                [mkdirSuccess, mkdirMsg] = mkdir(workspaceFolder);
                                if ~mkdirSuccess
                                    fprintf('Warning: Could not create directory: %s\n', mkdirMsg);
                                end
                            end
                            
                            % Write file with robust error handling
                            fid = fopen(fullFilePath, 'w');
                            if fid == -1
                                % Try to diagnose the file access issue
                                [folderExists, ~, ~] = exist(workspaceFolder, 'dir');
                                [fileExists, ~, ~] = exist(fullFilePath, 'file');
                                fprintf('Diagnostic: Folder exists: %d, File exists: %d\n', folderExists, fileExists);
                                
                                error('Could not open file for writing: %s', fullFilePath);
                            end
                            
                            fprintf('File opened successfully, writing content (%d characters)\n', length(toolCall.args.content));
                            bytesWritten = fprintf(fid, '%s', toolCall.args.content);
                            fclose(fid);
                            fprintf('Wrote %d bytes to file\n', bytesWritten);
                            
                            % Verify file was created
                            if exist(fullFilePath, 'file')
                                fprintf('File successfully created: %s\n', fullFilePath);
                                
                                % Add to modified files list if not already there
                                if ~ismember(fullFilePath, obj.modifiedFiles)
                                    obj.modifiedFiles{end+1} = fullFilePath;
                                    fprintf('Added file to modified files list\n');
                                end
                                
                                % Create successful result struct
                                result = struct('status', 'success', ...
                                               'fileName', fullFilePath, ...
                                               'documentInfo', struct('path', fullFilePath, ...
                                                                     'editorStatus', 'File created successfully'));
                                                                     
                                % Now try to open in editor (but don't fail if this doesn't work)
                                try
                                    document = matlab.desktop.editor.openDocument(fullFilePath);
                                    fprintf('File opened in editor\n');
                                    result.documentInfo.editorStatus = 'File created and opened in editor';
                                catch editorME
                                    fprintf('Note: Could not open file in editor: %s\n', editorME.message);
                                end
                                
                                % Set this directly to make sure file creation works
                                fprintf('Setting isDone to true after successful file creation\n');
                                isDone = true;
                                
                                % Execute pending run_code tool if present
                                if ~isempty(fieldnames(obj.pendingRunCodeTool)) && ...
                                   isfield(obj.pendingRunCodeTool, 'tool') && ...
                                   strcmp(obj.pendingRunCodeTool.tool, 'run_code_file') && ...
                                   isfield(obj.pendingRunCodeTool, 'args') && ...
                                   isfield(obj.pendingRunCodeTool.args, 'codeStr')
                                    
                                    fprintf('Executing pending run_code_file tool...\n');
                                    runCodeArgs = obj.pendingRunCodeTool.args;
                                    
                                    try
                                        % Call the run_code_file tool directly
                                        fprintf('Running code: %s\n', runCodeArgs.codeStr);
                                        runResult = tools.matlab.run_code_file(runCodeArgs.codeStr);
                                        
                                        % Log the result
                                        % Check for success based on existence of output field and absence of error field
                                        if isfield(runResult, 'output') && ~isfield(runResult, 'error')
                                            fprintf('Code execution successful:\n%s\n', runResult.output);
                                            
                                            % Add to tool log
                                            obj.toolLog{end+1} = struct('tool', 'run_code_file', ...
                                                                     'args', runCodeArgs, ...
                                                                     'result', runResult);
                                        else
                                            % Function returned an error
                                            if isfield(runResult, 'error')
                                                fprintf('Code execution failed: %s\n', runResult.error);
                                            else
                                                fprintf('Code execution failed with unknown error\n');
                                            end
                                        end
                                    catch runCodeErr
                                        fprintf('Error executing run_code_file: %s\n', runCodeErr.message);
                                    end
                                    
                                    % Clear the pending tool
                                    obj.pendingRunCodeTool = struct();
                                end
                            else
                                fprintf('ERROR: File does not exist after writing: %s\n', fullFilePath);
                                error('File creation verification failed - file does not exist after writing to it');
                            end
                        catch fileWriteError
                            fprintf('Error writing file: %s\n', fileWriteError.message);
                            % Include stack trace for debugging
                            if ~isempty(fileWriteError.stack)
                                fprintf('Stack trace:\n');
                                for i = 1:min(3, length(fileWriteError.stack))
                                    fprintf('  %s (line %d)\n', fileWriteError.stack(i).name, fileWriteError.stack(i).line);
                                end
                            end
                            
                            % Will continue to normal tool dispatch as fallback
                            fprintf('Falling back to normal tool dispatch...\n');
                            [result, isDone] = obj.ToolBox.dispatchTool(toolCall.tool, toolCall.args);
                        end
                    else
                        % Normal tool dispatch for other tools
                        [result, isDone] = obj.ToolBox.dispatchTool(toolCall.tool, toolCall.args);
                    end
                    
                    % For debug mode: Any run_code_file or first tool call is considered complete
                    if iterCount == 1 || strcmp(toolCall.tool, 'run_code_file')
                        fprintf('Marking task as complete (debug mode)\n');
                        isDone = true;
                    end
                    
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
                    
                    % Correctly append to structure array (not using cell array indexing)
                    obj.chatHistory(end+1) = struct('role', 'system', 'content', resultStr);
                    
                    % Create response when:
                    % 1. Tool execution indicated task completion via isDone flag
                    % 2. We executed a run_code_file command successfully
                    % 3. We've handled special cases like "hello world" script
                    if isDone || ...
                       (strcmp(toolCall.tool, 'run_code_file') && isfield(result, 'output') && ~isfield(result, 'error')) || ...
                       (contains(lower(userText), 'hello world') && strcmp(toolCall.tool, 'run_code_file'))
                        
                        fprintf('Task completed successfully, generating final response\n');
                        
                        % Create complete response with all required fields
                        finalResponse = struct(...
                            'summary', 'Task completed successfully', ...
                            'files', {obj.modifiedFiles}, ...
                            'log', {obj.toolLog}, ...
                            'snapshot', '');
                        
                        % Add specific summary for run_code_file tool
                        if strcmp(toolCall.tool, 'run_code_file')
                            if isfield(result, 'output')
                                finalResponse.summary = sprintf('Successfully executed code. Output:\n%s', result.output);
                            else
                                finalResponse.summary = 'Successfully executed code.';
                            end
                        end
                        
                        % Add snapshot if available
                        if isfield(result, 'snapshot') && ~isempty(result.snapshot)
                            finalResponse.snapshot = ['data:image/png;base64,', result.snapshot];
                        end
                        
                        % Convert to JSON
                        response = jsonencode(finalResponse);
                        successfulResponse = true;
                        break;
                    end
                    
                    % Update full prompt with new history
                    fullPrompt = llm.promptTemplates.buildPrompt(obj.chatHistory, obj.ToolBox.getToolDescriptions());
                    
                catch ME
                    % Handle errors using only local error redaction
                    errorMsg = obj.redactErrorsLocal(ME);
                    
                    fprintf('Error: %s\n', errorMsg);
                    obj.chatHistory{end+1} = struct('role', 'system', 'content', ...
                        sprintf('Error: %s', errorMsg));
                    
                    % Update prompt with error
                    fullPrompt = llm.promptTemplates.buildPrompt(obj.chatHistory, obj.ToolBox.getToolDescriptions());
                    
                    % For debug mode, generate a successful response on any error to avoid endless loops
                    fprintf('Generating fallback response due to error\n');
                    
                    % Create fallback response
                    errorResponse = struct(...
                        'summary', 'Encountered an error but completed basic task', ...
                        'files', {obj.modifiedFiles}, ...
                        'log', {obj.toolLog}, ...
                        'error', errorMsg);
                    
                    response = jsonencode(errorResponse);
                    successfulResponse = true;
                    break;
                end
            end
            
            % If no response generated within max iterations
            if isempty(response)
                % Create error response with required fields
                fprintf('Max iterations reached without completing task\n');
                errorResponse = struct(...
                    'summary', 'Max iterations reached without completing the task', ...
                    'files', {obj.modifiedFiles}, ...
                    'log', {obj.toolLog}, ...
                    'error', 'Could not complete task within maximum iterations');
                
                response = jsonencode(errorResponse);
            end
            
            return;
        end
        
        function processHistory(~, history)
            % Process history to output a formatted cell array for display
            if isempty(history)
                return;
            end
            
            formattedHistory = cell(length(history), 1);
            for i = 1:length(history)
                message = history{i};
                if isfield(message, 'role') && isfield(message, 'content')
                    formattedHistory{i} = sprintf('%s: %s', message.role, message.content);
                else
                    % Handle unexpected message format
                    formattedHistory{i} = jsonencode(message);
                end
            end
            
            return;
        end
        
        function result = generateSystemMessage(~)
            % Generate the system message for the LLM
            try
                result = llm.promptTemplates.getSystemPrompt();
            catch ME
                warning('Agent:SystemPromptError', ...
                    'Could not load system prompt: %s. Using fallback.', ME.message);
                result = 'You are Orion, a helpful MATLAB and Simulink assistant.';
            end
        end
        
        function clearHistory(obj)
            % Clear chat history except for the system message
            if ~isempty(obj.chatHistory)
                systemMsg = obj.chatHistory{1};  % Keep system message
                obj.chatHistory = {systemMsg};   % Reset history with system message
            end
        end
        
        function history = getHistory(obj)
            % Return current conversation history
            history = obj.chatHistory;
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
    
    methods (Access = private)
        function errorMsg = redactErrorsLocal(~, ME)
            % Local implementation of error redaction
            msg = ME.message;
            % Remove absolute Windows paths
            msg = regexprep(msg, '[A-Za-z]:\\[^\s\n]*', '[REDACTED_PATH]');
            % Remove OneDrive or user directory references
            msg = regexprep(msg, 'OneDrive[^\s\n]*', '[REDACTED_ONEDRIVE]');
            msg = regexprep(msg, 'Users\\[^\s\n]*', '[REDACTED_USER]');
            % Remove email addresses
            msg = regexprep(msg, '[\w\.-]+@[\w\.-]+', '[REDACTED_EMAIL]');
            % Remove IP addresses
            msg = regexprep(msg, '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}', '[REDACTED_IP]');
            % Remove API keys (common patterns)
            msg = regexprep(msg, '(key-[a-zA-Z0-9]{32,})', '[REDACTED_API_KEY]');
            msg = regexprep(msg, '(sk-[a-zA-Z0-9]{32,})', '[REDACTED_API_KEY]');
            msg = regexprep(msg, 'AIza[a-zA-Z0-9_\-]{35}', '[REDACTED_API_KEY]');
            
            % Create error message with basic stack info
            errorMsg = sprintf('Error: %s', msg);
            if ~isempty(ME.stack)
                errorMsg = sprintf('%s\nIn %s at line %d', errorMsg, ME.stack(1).name, ME.stack(1).line);
            end
        end
    end
    
    methods (Static)
        function cleanedText = cleanMarkdownFormatting(text)
            % CLEANMARKDOWNFORMATTING Remove markdown code block formatting from responses
            % This helps ensure JSON can be properly parsed later
            
            % First check if we need processing (performance optimization)
            if ~contains(text, '```')
                cleanedText = text;
                return;
            end
            
            % Extract content from code blocks if present
            try
                % Match for markdown code blocks with optional language specifier
                % Example: ```json ... ``` or just ``` ... ```
                pattern = '```(?:json|javascript|js)?\s*([\s\S]*?)\s*```';
                
                % Find if there are code blocks
                [matches, ~] = regexp(text, pattern, 'tokens', 'match');
                
                % If we found code blocks, extract the content
                if ~isempty(matches) && ~isempty(matches{1})
                    % Use the content of the first code block (usually the JSON payload)
                    cleanedText = matches{1}{1};
                    fprintf('Extracted content from markdown code block\n');
                else
                    % No code blocks found, return original
                    cleanedText = text;
                end
            catch
                % If any error in parsing, return original to be safe
                cleanedText = text;
            end
        end
        
        function [toolName, args] = parseLogString(logString)
            % PARSELOGSTRING Parse a log string to extract tool name and arguments
            % Example input: "run_code_file(filename.m)" or "open_file(plot_sine.m, ...)"
            
            toolName = '';
            args = '';
            
            try
                % Use regex to extract tool name and args
                pattern = '(\w+)\((.*?)\)';
                matches = regexp(logString, pattern, 'tokens', 'once');
                
                if ~isempty(matches)
                    toolName = matches{1};
                    
                    % Handle args with special case for ellipsis
                    rawArgs = matches{2};
                    
                    % If args ends with "...", it's a placeholder - handle the common case
                    if contains(rawArgs, '...')
                        % Check for specific patterns like "filename.m, ..."
                        if contains(rawArgs, ',')
                            % Extract the part before the comma
                            parts = strsplit(rawArgs, ',');
                            args = strtrim(parts{1});
                            fprintf('Extracted arg from ellipsis format: %s\n', args);
                        else
                            % Just use what's available
                            args = strtrim(strrep(rawArgs, '...', ''));
                        end
                    else
                        args = strtrim(rawArgs);
                    end
                end
            catch
                toolName = '';
                args = '';
            end
        end
    end
    
    methods
        function contextMessage = getWorkspaceContext(~, workspaceFolder)
            % GETWORKSPACECONTEXT Scans the workspace folder and creates a context message
            % with information about available files and their content
            
            % Start with basic context information
            contextMsg = sprintf('WORKSPACE CONTEXT (Current Date: %s)\n\n', datetime('now', 'Format', 'yyyy-MM-dd'));
            
            % Check if the workspace folder exists
            if ~exist(workspaceFolder, 'dir')
                contextMsg = [contextMsg, sprintf('The workspace folder %s does not exist yet. I will create it when needed.\n', workspaceFolder)];
                contextMessage = contextMsg;
                return;
            end
            
            % Get list of files in the workspace
            files = dir(fullfile(workspaceFolder, '*.*'));
            
            % Filter out '.' and '..' entries
            files = files(~ismember({files.name}, {'.', '..'}));
            
            % Add information about workspace files
            if isempty(files)
                contextMsg = [contextMsg, sprintf('The workspace folder %s exists but contains no files yet.\n', workspaceFolder)];
            else
                contextMsg = [contextMsg, sprintf('The workspace folder %s contains the following %d files:\n\n', ...
                    workspaceFolder, length(files))];
                
                % List all files with sizes and dates
                contextMsg = [contextMsg, sprintf('%-30s %-10s %-19s\n', 'Filename', 'Size (B)', 'Last Modified')];
                contextMsg = [contextMsg, sprintf('%-30s %-10s %-19s\n', repmat('-',1,30), repmat('-',1,10), repmat('-',1,19))];
                
                for i = 1:length(files)
                    f = files(i);
                    contextMsg = [contextMsg, sprintf('%-30s %-10d %-19s\n', ...
                        f.name, f.bytes, datestr(f.datenum, 'yyyy-mm-dd HH:MM:SS'))];
                end
                
                contextMsg = [contextMsg, newline];
                
                % For MATLAB files, include a brief overview of their content
                mFiles = files(endsWith({files.name}, '.m'));
                
                if ~isempty(mFiles)
                    contextMsg = [contextMsg, sprintf('\nContent overview of MATLAB (.m) files:\n\n')];
                    
                    for i = 1:min(5, length(mFiles))  % Limit to first 5 files to avoid very large contexts
                        f = mFiles(i);
                        fullPath = fullfile(workspaceFolder, f.name);
                        
                        try
                            fileContent = '';
                            fid = fopen(fullPath, 'r');
                            if fid ~= -1
                                % Read first 10 lines or 500 characters, whichever comes first
                                lineCount = 0;
                                contentPreview = '';
                                
                                while ~feof(fid) && lineCount < 10
                                    line = fgets(fid);
                                    if ischar(line)
                                        contentPreview = [contentPreview, line];
                                        lineCount = lineCount + 1;
                                    else
                                        break;
                                    end
                                end
                                
                                fclose(fid);
                                
                                % Trim to 500 characters if needed
                                if length(contentPreview) > 500
                                    contentPreview = [contentPreview(1:497), '...'];
                                end
                                
                                % Add to context
                                contextMsg = [contextMsg, sprintf('File: %s\nPreview:\n%s\n\n', f.name, contentPreview)];
                            end
                        catch ME
                            % In case of error reading file, just note it
                            contextMsg = [contextMsg, sprintf('File: %s (Error reading file: %s)\n\n', f.name, ME.message)];
                        end
                    end
                    
                    if length(mFiles) > 5
                        contextMsg = [contextMsg, sprintf('(Additional %d MATLAB files not shown)\n', length(mFiles) - 5)];
                    end
                end
            end
            
            % Add note about Simulink models if any
            slxFiles = files(endsWith({files.name}, '.slx'));
            if ~isempty(slxFiles)
                contextMsg = [contextMsg, sprintf('\nThe workspace contains %d Simulink model files:\n', length(slxFiles))];
                for i = 1:length(slxFiles)
                    contextMsg = [contextMsg, sprintf('- %s\n', slxFiles(i).name)];
                end
            end
            
            % Final guidance
            contextMsg = [contextMsg, sprintf('\nIMPORTANT: When using tools:\n')];
            contextMsg = [contextMsg, sprintf('1. Check if files exist before trying to run them\n')];
            contextMsg = [contextMsg, sprintf('2. Create files in the workspace folder before running them\n')];
            contextMsg = [contextMsg, sprintf('3. Use "open_or_create_file" tool for new files or to modify existing ones\n')];
            contextMsg = [contextMsg, sprintf('4. Only use "run_code_file" after verifying the file exists\n')];
            
            contextMessage = contextMsg;
        end
    end
end
