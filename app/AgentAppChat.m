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

    % Callbacks that handle component events
    methods (Access = private)

        % Button pushed function: clearButton
        function clear_agent_thought_process(app, event)
            % To Do
        end

        % Button pushed function: SendButton
        function send_user_input_to_llm(app, event)
            % To Do
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

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end