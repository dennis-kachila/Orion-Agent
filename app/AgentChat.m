classdef AgentChat < matlab.apps.AppBase
    % AGENTCHAT UI interface for Orion Agent
    % Chat pane + live PNG preview via Simulink.BlockDiagram.createSnapshot

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure           matlab.ui.Figure
        ChatPanel          matlab.ui.container.Panel
        SendButton         matlab.ui.control.Button
        InputTextArea      matlab.ui.control.TextArea
        ChatHistoryTextArea matlab.ui.control.TextArea
        PreviewPanel       matlab.ui.container.Panel
        PreviewImage       matlab.ui.control.Image
        ModelNameLabel     matlab.ui.control.Label
        ClearButton        matlab.ui.control.Button
        StatusLabel        matlab.ui.control.Label
        
        % Non-GUI properties
        Agent              % Reference to the agent instance
        CurrentModelName   % Name of the currently active model
    end

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
            scrollPos = app.ChatHistoryTextArea.Position(4);
            app.ChatHistoryTextArea.scroll('bottom');
        end
        
        function updatePreview(app, imagePath)
            % Update the preview image with a Simulink model snapshot
            
            try
                if exist(imagePath, 'file')
                    % Load image from file
                    app.PreviewImage.ImageSource = imagePath;
                else
                    % Try to create a snapshot if model is open
                    if ~isempty(app.CurrentModelName) && bdIsLoaded(app.CurrentModelName)
                        pngData = Simulink.BlockDiagram.createSnapshot(app.CurrentModelName);
                        
                        % Save PNG to temporary file
                        tempFile = [tempname, '.png'];
                        fid = fopen(tempFile, 'wb');
                        fwrite(fid, pngData);
                        fclose(fid);
                        
                        % Display the image
                        app.PreviewImage.ImageSource = tempFile;
                        app.ModelNameLabel.Text = ['Model: ', app.CurrentModelName];
                    end
                end
            catch
                % Clear image if update fails
                app.PreviewImage.ImageSource = '';
                app.StatusLabel.Text = 'Error updating preview';
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
                        app.updateChatHistory(['Summary: ', responseData.summary], 'assistant');
                    end
                    
                    % Display files if present
                    if isfield(responseData, 'files') && ~isempty(responseData.files)
                        fileList = 'Files:';
                        for i = 1:numel(responseData.files)
                            fileList = [fileList, '\n- ', responseData.files{i}];
                        end
                        app.updateChatHistory(fileList, 'assistant');
                    end
                    
                    % Display log if present
                    if isfield(responseData, 'log') && ~isempty(responseData.log)
                        logMsg = 'Tool calls:';
                        for i = 1:min(5, numel(responseData.log))  % Show at most 5 tool calls
                            logMsg = [logMsg, '\n- ', responseData.log{i}];
                        end
                        if numel(responseData.log) > 5
                            logMsg = [logMsg, '\n(', num2str(numel(responseData.log) - 5), ' more tool calls not shown)'];
                        end
                        app.updateChatHistory(logMsg, 'assistant');
                    end
                    
                    % Display error if present
                    if isfield(responseData, 'error') 
                        app.updateChatHistory(['Error: ', responseData.error], 'system');
                    end
                    
                    % Update snapshot if present
                    if isfield(responseData, 'snapshot') && ~isempty(responseData.snapshot)
                        % Extract base64 data
                        if startsWith(responseData.snapshot, 'data:image/png;base64,')
                            base64Data = strrep(responseData.snapshot, 'data:image/png;base64,', '');
                            
                            % Decode and save to temp file
                            imageData = base64decode(base64Data);
                            tempFile = [tempname, '.png'];
                            fid = fopen(tempFile, 'wb');
                            fwrite(fid, imageData);
                            fclose(fid);
                            
                            % Update preview
                            app.updatePreview(tempFile);
                        end
                    end
                    
                    % Update model name if present
                    if isfield(responseData, 'modelName')
                        app.CurrentModelName = responseData.modelName;
                        app.ModelNameLabel.Text = ['Model: ', app.CurrentModelName];
                    end
                    
                elseif isstruct(response)
                    % Legacy format - direct struct response
                    % This branch handles the old behavior for compatibility
                    
                    % Check for snapshot in the response
                    if isfield(response, 'snapshot') && ~isempty(response.snapshot)
                        % Decode and save base64 image data
                        pngData = base64decode(response.snapshot);
                        tempFile = [tempname, '.png'];
                        fid = fopen(tempFile, 'wb');
                        fwrite(fid, pngData);
                        fclose(fid);
                        
                        % Update preview
                        app.updatePreview(tempFile);
                    end
                    
                    % Update model name if present
                    if isfield(response, 'modelName')
                        app.CurrentModelName = response.modelName;
                        app.ModelNameLabel.Text = ['Model: ', app.CurrentModelName];
                    end
                    
                    % Format response for display
                    if isfield(response, 'status') && strcmp(response.status, 'error') && isfield(response, 'error')
                        % Display error
                        displayText = ['Error: ', response.error];
                        app.updateChatHistory(displayText, 'system');
                    else
                        % Display success and relevant fields
                        displayText = '';
                        
                        if isfield(response, 'status')
                            displayText = [displayText, 'Status: ', response.status, '\n'];
                        end
                        
                        % Add other relevant fields based on the tool
                        fields = fieldnames(response);
                        relevantFields = setdiff(fields, {'status', 'snapshot', 'error'});
                        
                        for i = 1:length(relevantFields)
                            field = relevantFields{i};
                            value = response.(field);
                            
                            % Format field based on type
                            if ischar(value) || isstring(value)
                                displayText = [displayText, field, ': ', char(value), '\n'];
                            elseif isnumeric(value) && isscalar(value)
                                displayText = [displayText, field, ': ', num2str(value), '\n'];
                            elseif islogical(value) && isscalar(value)
                                if value
                                    displayText = [displayText, field, ': true\n'];
                                else
                                    displayText = [displayText, field, ': false\n'];
                                end
                            end
                        end
                        
                        app.updateChatHistory(displayText, 'assistant');
                    end
                elseif ischar(response) || isstring(response)
                    % Handle plain text response
                    if isJsonResponse
                        % If it's valid JSON but not a struct, show formatted
                        app.updateChatHistory('Response (JSON):\n', 'assistant');
                        app.updateChatHistory(response, 'assistant');
                    else
                        % Display normal text response
                        app.updateChatHistory(char(response), 'assistant');
                    end
                else
                    % Unknown response type
                    app.updateChatHistory('Received response in unsupported format', 'system');
                end
                
                % Update status
                app.StatusLabel.Text = 'Ready';
            catch ME
                % Handle display errors
                app.StatusLabel.Text = ['Display error: ', ME.message];
            end
        end
        
        function SendButtonPushed(app, ~)
            % Execute when Send button is pushed
            
            % Get user input
            userInput = app.InputTextArea.Value;
            
            % Skip if empty
            if isempty(userInput)
                return;
            end
            
            % Display user message in chat
            if iscell(userInput)
                userInput = strjoin(userInput, '\n');
            end
            app.updateChatHistory(userInput, 'user');
            
            % Clear input
            app.InputTextArea.Value = '';
            
            % Update status
            app.StatusLabel.Text = 'Processing...';
            drawnow;
            
            try
                % Send to agent for processing
                response = app.Agent.processUserInput(userInput);
                
                % Process and display response
                app.processAgentResponse(response);
            catch ME
                % Display error
                errorMsg = ['Agent error: ', ME.message];
                app.updateChatHistory(errorMsg, 'system');
                app.StatusLabel.Text = 'Error';
            end
        end
        
        function ClearButtonPushed(app, ~)
            % Execute when Clear button is pushed
            
            % Clear chat history
            app.ChatHistoryTextArea.Value = {};
            
            % Clear agent history
            app.Agent.clearHistory();
            
            % Update status
            app.StatusLabel.Text = 'Chat history cleared';
        end
        
        function InputTextAreaKeyPress(app, event)
            % Execute on key press in input text area
            
            % Submit on Ctrl+Enter or Shift+Enter
            if (strcmp(event.Modifier, 'control') || strcmp(event.Modifier, 'shift')) && strcmp(event.Key, 'return')
                app.SendButtonPushed();
            end
        end
    end

    % Component initialization
    methods (Access = private)
        function createComponents(app)
            % Create the UI components
            
            % Create main figure
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100, 100, 800, 600];
            app.UIFigure.Name = 'Orion Agent Chat';
            app.UIFigure.Icon = '';
            
            % Create chat panel
            app.ChatPanel = uipanel(app.UIFigure);
            app.ChatPanel.Title = 'Chat';
            app.ChatPanel.Position = [10, 10, 400, 580];
            
            % Create chat history text area
            app.ChatHistoryTextArea = uitextarea(app.ChatPanel);
            app.ChatHistoryTextArea.Position = [10, 100, 380, 450];
            app.ChatHistoryTextArea.Editable = 'off';
            
            % Create input text area
            app.InputTextArea = uitextarea(app.ChatPanel);
            app.InputTextArea.Position = [10, 40, 300, 50];
            app.InputTextArea.KeyPressFcn = createCallbackFcn(app, @InputTextAreaKeyPress, true);
            
            % Create send button
            app.SendButton = uibutton(app.ChatPanel, 'push');
            app.SendButton.Position = [320, 40, 70, 50];
            app.SendButton.Text = 'Send';
            app.SendButton.ButtonPushedFcn = createCallbackFcn(app, @SendButtonPushed, true);
            
            % Create clear button
            app.ClearButton = uibutton(app.ChatPanel, 'push');
            app.ClearButton.Position = [320, 10, 70, 25];
            app.ClearButton.Text = 'Clear';
            app.ClearButton.ButtonPushedFcn = createCallbackFcn(app, @ClearButtonPushed, true);
            
            % Create status label
            app.StatusLabel = uilabel(app.ChatPanel);
            app.StatusLabel.Position = [10, 10, 300, 25];
            app.StatusLabel.Text = 'Ready';
            
            % Create preview panel
            app.PreviewPanel = uipanel(app.UIFigure);
            app.PreviewPanel.Title = 'Model Preview';
            app.PreviewPanel.Position = [420, 10, 370, 580];
            
            % Create model name label
            app.ModelNameLabel = uilabel(app.PreviewPanel);
            app.ModelNameLabel.Position = [10, 550, 350, 20];
            app.ModelNameLabel.Text = 'Model: None';
            
            % Create preview image
            app.PreviewImage = uiimage(app.PreviewPanel);
            app.PreviewImage.Position = [10, 10, 350, 530];
            
            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % Public methods
    methods (Access = public)
        function app = AgentChat
            % Constructor
            
            % Create and configure components
            createComponents(app);
            
            % Initialize agent
            app.Agent = agent.Agent();
            app.CurrentModelName = '';
            
            % Welcome message
            welcomeMessage = ['Welcome to Orion Agent! I can help you create and simulate MATLAB scripts and Simulink models. ', ...
                             'Tell me what you would like to build.'];
            app.updateChatHistory(welcomeMessage, 'assistant');
            
            % Register app close callback
            app.UIFigure.CloseRequestFcn = @(~,~)app.closeApp();
            
            % Show the app
            if nargout == 0
                clear app
            end
        end
        
        function closeApp(app)
            % Clean up when app is closed
            
            % Close any open models
            if ~isempty(app.CurrentModelName) && bdIsLoaded(app.CurrentModelName)
                close_system(app.CurrentModelName, 0);
            end
            
            % Delete the figure
            delete(app.UIFigure);
        end
    end
end

function decoded = base64decode(encoded)
    % Base64 decode function
    import org.apache.commons.codec.binary.Base64;
    decoded = Base64.decodeBase64(uint8(encoded));
end
