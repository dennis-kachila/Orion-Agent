classdef AgentAppChat < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                   matlab.ui.Figure
        ImageOrionLogo             matlab.ui.control.Image
        OrionAgentWorkflowPanel    matlab.ui.container.Panel
        ModelLogTextAreaLabel      matlab.ui.control.Label
        SimulinkModelPreviewLabel  matlab.ui.control.Label
        ModelSnapshotPreviewImage  matlab.ui.control.Image
        StatusLabel                matlab.ui.control.Label
        AgentWorkFlowLogTextArea   matlab.ui.control.TextArea
        AgentStatusLamp            matlab.ui.control.Lamp
        clearButton                matlab.ui.control.Button
        CHATPanel                  matlab.ui.container.Panel
        StopButton                 matlab.ui.control.Button
        UserInputTextArea          matlab.ui.control.TextArea
        ChatHistoryTextArea        matlab.ui.control.TextArea
        SendButton                 matlab.ui.control.Button
    end


    % Public properties that correspond to the Simulink model
    properties (Access = public, Transient)
        Simulation simulink.Simulation
    end
    
    % Properties for Agent functionality
    properties (Access = private)
        Agent              % Reference to the agent instance
        CurrentModelName   % Name of the currently active model
        IsProcessing       % Flag to indicate if the agent is currently processing
        TaskTimer          % Timer for long-running tasks
        CurrentSnapshot    % Current model snapshot data
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Button pushed function: clearButton
        function clear_agent_thought_process(app, ~)
            % Clear the workflow log
            app.AgentWorkFlowLogTextArea.Value = {};
            app.updateWorkflowLog('Workflow log cleared');
            
            % Reset status indicators
            app.setAgentStatus('Ready');
        end

        % Button pushed function: SendButton
        function send_user_input_to_llm(app, ~)
            % Get user input
            userInput = app.UserInputTextArea.Value;
            
            % Skip if empty
            if isempty(userInput)
                return;
            end
            
            % Combine multi-line input into a single string
            if iscell(userInput)
                userInput = strjoin(userInput, ' ');
            end
            
            % Check if agent is already processing
            if app.IsProcessing
                app.updateWorkflowLog('Operation in progress. Please wait or click Stop.');
                return;
            end
            
            % Display user message in chat
            app.updateChatHistory(userInput, 'user');
            
            % Clear input
            app.UserInputTextArea.Value = {};
            
            % Update status
            app.setAgentStatus('Processing');
            app.IsProcessing = true;
            app.updateWorkflowLog('Processing request: ' + string(userInput));
            
            % Create a timer to run the agent processing
            app.TaskTimer = timer(...
                'ExecutionMode', 'singleShot', ...
                'StartDelay', 0.1, ... % Short delay to let UI update
                'TimerFcn', @(~,~) app.processAgentRequest(userInput), ...
                'ErrorFcn', @(~,~) app.handleTimerError() ...
            );
            
            % Start timer
            start(app.TaskTimer);
        end
        
        % Process agent request in timer callback to keep UI responsive
        function processAgentRequest(app, userInput)
            try
                % Send to agent for processing
                response = app.Agent.processUserInput(userInput);
                
                % Update UI from timer callback context
                executeInUIContextIfAvailable(app.UIFigure, @() app.processAgentResponse(response));
                executeInUIContextIfAvailable(app.UIFigure, @() app.setAgentStatus('Ready'));
                
                % Check for model updates
                if ~isempty(app.CurrentModelName)
                    executeInUIContextIfAvailable(app.UIFigure, @() app.updateModelPreview(app.CurrentModelName));
                end
                
            catch ME
                % Handle errors
                executeInUIContextIfAvailable(app.UIFigure, @() app.updateWorkflowLog(['Error: ', ME.message]));
                executeInUIContextIfAvailable(app.UIFigure, @() app.updateChatHistory(['Agent error: ', ME.message], 'system'));
                executeInUIContextIfAvailable(app.UIFigure, @() app.setAgentStatus('Error'));
            end
            
            % Reset processing state
            executeInUIContextIfAvailable(app.UIFigure, @() app.finishProcessing());
        end
        
        % Button pushed function: StopButton
        function stopExecution(app, ~)
            % Attempt to stop any ongoing operation
            app.updateWorkflowLog('Stop requested. Attempting to cancel operation...');
            
            % Stop timer if running
            if ~isempty(app.TaskTimer) && isvalid(app.TaskTimer)
                if strcmp(app.TaskTimer.Running, 'on')
                    stop(app.TaskTimer);
                    delete(app.TaskTimer);
                    app.TaskTimer = [];
                end
            end
            
            % Reset processing state
            app.finishProcessing();
            app.setAgentStatus('Ready');
            app.updateWorkflowLog('Operation cancelled.');
        end
        
        function finishProcessing(app)
            % Reset processing flags
            app.IsProcessing = false;
            
            % Clean up timer if it exists
            if ~isempty(app.TaskTimer) && isvalid(app.TaskTimer)
                delete(app.TaskTimer);
                app.TaskTimer = [];
            end
        end
        
        function handleTimerError(app)
            % Handle errors from the timer task
            app.updateWorkflowLog('Error in background task');
            app.setAgentStatus('Error');
            app.finishProcessing();
        end
    end

    % Utility methods for updating the UI
    methods (Access = private)
        function updateChatHistory(app, message, role)
            % Update the chat history with a new message
            
            % Get current content
            currentContent = app.ChatHistoryTextArea.Value;
            
            % Format based on role
            if strcmp(role, 'user')
                prefix = 'You: ';
                style = '';
            elseif strcmp(role, 'assistant')
                prefix = 'Orion: ';
                style = '';
            elseif strcmp(role, 'system')
                prefix = '>> ';
                style = '';
            else
                prefix = '';
                style = '';
            end
            
            % Add new message with appropriate styling
            formattedMessage = sprintf('%s%s%s\n\n', style, prefix, message);
            
            % Update text area
            if isempty(currentContent)
                app.ChatHistoryTextArea.Value = {formattedMessage};
            else
                if ischar(currentContent)
                    currentContent = {currentContent};
                end
                app.ChatHistoryTextArea.Value = [currentContent; {formattedMessage}];
            end
            
            % Scroll to bottom
            drawnow;
            app.ChatHistoryTextArea.scroll('bottom');
        end
        
        function updateWorkflowLog(app, message)
            % Update the agent workflow log with a new message
            
            % Get current content
            currentContent = app.AgentWorkFlowLogTextArea.Value;
            
            % Format message with timestamp
            timestamp = datestr(now, 'HH:MM:SS');
            formattedMessage = sprintf('[%s] %s\n', timestamp, message);
            
            % Update text area
            if isempty(currentContent)
                app.AgentWorkFlowLogTextArea.Value = {formattedMessage};
            else
                if ischar(currentContent)
                    currentContent = {currentContent};
                end
                app.AgentWorkFlowLogTextArea.Value = [currentContent; {formattedMessage}];
            end
            
            % Scroll to bottom
            drawnow;
            app.AgentWorkFlowLogTextArea.scroll('bottom');
        end
        
        function setAgentStatus(app, status)
            % Update agent status indicators
            
            app.StatusLabel.Text = status;
            
            % Update status lamp color based on status
            switch lower(status)
                case 'ready'
                    app.AgentStatusLamp.Color = [0 0.8 0]; % Green
                case 'processing'
                    app.AgentStatusLamp.Color = [0.9290 0.6940 0.1250]; % Yellow/Orange
                case 'error'
                    app.AgentStatusLamp.Color = [0.8 0 0]; % Red
                otherwise
                    app.AgentStatusLamp.Color = [0.651 0.651 0.651]; % Gray (default)
            end
        end
        
        function updateModelPreview(app, modelName)
            % Update the preview image with a Simulink model snapshot
            
            try
                % Check if model is open
                if ~isempty(modelName) && bdIsLoaded(modelName)
                    app.updateWorkflowLog(sprintf('Generating snapshot of model: %s', modelName));
                    
                    % Create snapshot and save to base64
                    pngData = Simulink.BlockDiagram.createSnapshot(modelName);
                    
                    % Save PNG to temporary file
                    tempFile = [tempname, '.png'];
                    fid = fopen(tempFile, 'wb');
                    fwrite(fid, pngData);
                    fclose(fid);
                    
                    % Store current snapshot
                    app.CurrentSnapshot = pngData;
                    
                    % Update display
                    app.ModelSnapshotPreviewImage.ImageSource = tempFile;
                    app.SimulinkModelPreviewLabel.Text = ['Model: ', modelName];
                    app.CurrentModelName = modelName;
                else
                    app.updateWorkflowLog('No model available to display');
                end
            catch ME
                app.updateWorkflowLog(['Error creating model preview: ', ME.message]);
                app.ModelSnapshotPreviewImage.ImageSource = fullfile(fileparts(mfilename('fullpath')), 'default_model_snapshot_Placeholder.png');
            end
        end
        
        function processAgentResponse(app, response)
            % Process and display the agent's response
            
            try
                % Try to parse response as JSON
                try
                    responseData = jsondecode(response);
                    isJsonResponse = true;
                catch
                    isJsonResponse = false;
                end
                
                % Handle different response types
                if isJsonResponse && isstruct(responseData)
                    % New JSON format response
                    
                    % Display summary if present
                    if isfield(responseData, 'summary')
                        app.updateChatHistory(responseData.summary, 'assistant');
                    end
                    
                    % Display files if present
                    if isfield(responseData, 'files') && ~isempty(responseData.files)
                        fileList = 'Modified files:';
                        for i = 1:numel(responseData.files)
                            [~, fname, fext] = fileparts(responseData.files{i});
                            fileList = [fileList, sprintf('\n- %s%s', fname, fext)];
                        end
                        app.updateWorkflowLog(fileList);
                    end
                    
                    % Process log entries for workflow display
                    if isfield(responseData, 'log') && ~isempty(responseData.log)
                        app.updateWorkflowLog('Tool execution log:');
                        
                        for i = 1:numel(responseData.log)
                            logItem = responseData.log{i};
                            
                            if isstruct(logItem) && isfield(logItem, 'tool') && isfield(logItem, 'args')
                                % Format the log entry nicely
                                toolName = logItem.tool;
                                argsStr = jsonencode(logItem.args);
                                app.updateWorkflowLog(sprintf('→ %s: %s', toolName, argsStr));
                            elseif ischar(logItem)
                                app.updateWorkflowLog(sprintf('→ %s', logItem));
                            end
                        end
                    end
                    
                    % Display error if present
                    if isfield(responseData, 'error') 
                        app.updateChatHistory(['Error: ', responseData.error], 'system');
                        app.updateWorkflowLog(['ERROR: ', responseData.error]);
                        app.setAgentStatus('Error');
                    end
                    
                    % Update snapshot if present
                    if isfield(responseData, 'snapshot') && ~isempty(responseData.snapshot)
                        % Extract base64 data
                        if startsWith(responseData.snapshot, 'data:image/png;base64,')
                            base64Data = strrep(responseData.snapshot, 'data:image/png;base64,', '');
                            
                            % Decode and save to temp file
                            imageData = app.base64decode(base64Data);
                            tempFile = [tempname, '.png'];
                            fid = fopen(tempFile, 'wb');
                            fwrite(fid, imageData);
                            fclose(fid);
                            
                            % Update preview
                            app.ModelSnapshotPreviewImage.ImageSource = tempFile;
                            app.CurrentSnapshot = imageData;
                        end
                    end
                    
                    % Update model name if present
                    if isfield(responseData, 'modelName')
                        app.CurrentModelName = responseData.modelName;
                        app.SimulinkModelPreviewLabel.Text = ['Model: ', app.CurrentModelName];
                        app.updateWorkflowLog(['Model set to: ', app.CurrentModelName]);
                    end
                    
                else
                    % Handle plain text or other response
                    if ischar(response) || isstring(response)
                        app.updateChatHistory(char(response), 'assistant');
                    else
                        app.updateChatHistory('Received response in unsupported format', 'system');
                    end
                end
                
            catch ME
                % Handle display errors
                app.updateWorkflowLog(['Error processing response: ', ME.message]);
                app.setAgentStatus('Error');
            end
        end
        
        function decoded = base64decode(~, encoded)
            % Base64 decode function
            import org.apache.commons.codec.binary.Base64;
            decoded = Base64.decodeBase64(uint8(encoded));
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Get the file path for locating images
            pathToMLAPP = fileparts(mfilename('fullpath'));

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 805 816];
            app.UIFigure.Name = 'MATLAB App';

            % Create CHATPanel
            app.CHATPanel = uipanel(app.UIFigure);
            app.CHATPanel.Title = 'CHAT';
            app.CHATPanel.Position = [15 54 385 640];

            % Create SendButton
            app.SendButton = uibutton(app.CHATPanel, 'push');
            app.SendButton.ButtonPushedFcn = createCallbackFcn(app, @send_user_input_to_llm, true);
            app.SendButton.Icon = fullfile(pathToMLAPP, 'direct.png');
            app.SendButton.Position = [315 55 61 37];
            app.SendButton.Text = 'Send';

            % Create ChatHistoryTextArea
            app.ChatHistoryTextArea = uitextarea(app.CHATPanel);
            app.ChatHistoryTextArea.Position = [18 158 350 448];

            % Create UserInputTextArea
            app.UserInputTextArea = uitextarea(app.CHATPanel);
            app.UserInputTextArea.Placeholder = 'Please start typing here..';
            app.UserInputTextArea.Position = [19 15 289 106];
            app.UserInputTextArea.Value = {'jjjij'; 'nknknldfdlmmdml'};

            % Create StopButton
            app.StopButton = uibutton(app.CHATPanel, 'push');
            app.StopButton.ButtonPushedFcn = createCallbackFcn(app, @stopExecution, true);
            app.StopButton.Icon = fullfile(pathToMLAPP, 'stop.png');
            app.StopButton.Position = [319 15 54 23];
            app.StopButton.Text = 'Stop';

            % Create OrionAgentWorkflowPanel
            app.OrionAgentWorkflowPanel = uipanel(app.UIFigure);
            app.OrionAgentWorkflowPanel.Title = 'Orion Agent Workflow';
            app.OrionAgentWorkflowPanel.Position = [410 54 388 753];

            % Create clearButton
            app.clearButton = uibutton(app.OrionAgentWorkflowPanel, 'push');
            app.clearButton.ButtonPushedFcn = createCallbackFcn(app, @clear_agent_thought_process, true);
            app.clearButton.Icon = fullfile(pathToMLAPP, 'broom.png');
            app.clearButton.Position = [311 9 62 35];
            app.clearButton.Text = 'clear';

            % Create AgentStatusLamp
            app.AgentStatusLamp = uilamp(app.OrionAgentWorkflowPanel);
            app.AgentStatusLamp.Position = [341 704 20 20];
            app.AgentStatusLamp.Color = [0.651 0.651 0.651];

            % Create AgentWorkFlowLogTextArea
            app.AgentWorkFlowLogTextArea = uitextarea(app.OrionAgentWorkflowPanel);
            app.AgentWorkFlowLogTextArea.Tag = 'agent workflow';
            app.AgentWorkFlowLogTextArea.Position = [13 55 360 261];

            % Create StatusLabel
            app.StatusLabel = uilabel(app.OrionAgentWorkflowPanel);
            app.StatusLabel.HorizontalAlignment = 'right';
            app.StatusLabel.Position = [213 703 120 22];
            app.StatusLabel.Text = 'Status';

            % Create ModelSnapshotPreviewImage
            app.ModelSnapshotPreviewImage = uiimage(app.OrionAgentWorkflowPanel);
            app.ModelSnapshotPreviewImage.Position = [13 355 360 336];
            app.ModelSnapshotPreviewImage.ImageSource = fullfile(pathToMLAPP, 'default_model_snapshot_Placeholder.png');

            % Create SimulinkModelPreviewLabel
            app.SimulinkModelPreviewLabel = uilabel(app.OrionAgentWorkflowPanel);
            app.SimulinkModelPreviewLabel.FontName = 'Yu Gothic UI Semilight';
            app.SimulinkModelPreviewLabel.FontAngle = 'italic';
            app.SimulinkModelPreviewLabel.Position = [26 703 132 22];
            app.SimulinkModelPreviewLabel.Text = 'Simulink Model Preview';

            % Create ModelLogTextAreaLabel
            app.ModelLogTextAreaLabel = uilabel(app.OrionAgentWorkflowPanel);
            app.ModelLogTextAreaLabel.FontName = 'Yu Gothic UI Semilight';
            app.ModelLogTextAreaLabel.FontAngle = 'italic';
            app.ModelLogTextAreaLabel.Position = [13 325 115 22];
            app.ModelLogTextAreaLabel.Text = 'Model Log Text Area';

            % Create ImageOrionLogo
            app.ImageOrionLogo = uiimage(app.UIFigure);
            app.ImageOrionLogo.ScaleMethod = 'scaleup';
            app.ImageOrionLogo.Position = [15 703 327 107];
            app.ImageOrionLogo.ImageSource = fullfile(pathToMLAPP, '2.png');

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = AgentAppChat

            % Create UIFigure and components
            createComponents(app)
            
            % Initialize properties
            app.Agent = agent.Agent();
            app.CurrentModelName = '';
            app.IsProcessing = false;
            app.TaskTimer = [];
            app.CurrentSnapshot = [];
            
            % Set initial UI state
            app.setAgentStatus('Ready');
            app.UserInputTextArea.Value = {};  % Clear default debug text
            
            % Display welcome message
            welcomeMessage = 'Welcome to Orion Agent! I can help you create and simulate MATLAB scripts and Simulink models. Tell me what you would like to build.';
            app.updateChatHistory(welcomeMessage, 'assistant');
            app.updateWorkflowLog('Agent initialized and ready');
            
            % Register app close function to clean up resources
            app.UIFigure.CloseRequestFcn = @(src,event)app.onAppClose(src,event);

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            if nargout == 0
                clear app
            end
        end
        
        % Function to handle app close event
        function onAppClose(app, ~, ~)
            % Clean up resources
            
            % Stop any running timer
            if ~isempty(app.TaskTimer) && isvalid(app.TaskTimer)
                stop(app.TaskTimer);
                delete(app.TaskTimer);
            end
            
            % Close any open models created by the agent
            if ~isempty(app.CurrentModelName) && bdIsLoaded(app.CurrentModelName)
                try
                    close_system(app.CurrentModelName, 0);
                catch
                    % Ignore errors when closing models
                end
            end
            
            % Delete the figure
            delete(app.UIFigure);
        end

        % Code that executes before app deletion
        function delete(app)
            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end