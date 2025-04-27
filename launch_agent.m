% LAUNCH_AGENT A simple launcher for the Orion Agent application
% Run this script from the main project directory to start the application

fprintf('=== Orion Agent Launcher (Debug Mode) ===\n');
fprintf('Current directory: %s\n', pwd);

% First, set up the paths
fprintf('Setting up paths...\n');
setup_paths;

% Test LLM configuration before launching
fprintf('Testing LLM configuration...\n');
try
    % Check for API key in environment
    geminiKey = getenv('GEMINI_API_KEY');
    if ~isempty(geminiKey)
        fprintf('✓ Gemini API key found in environment\n');
    else
        % Try to load from settings file
        if exist('llm_settings.mat', 'file')
            try
                load('llm_settings.mat', 'settings');
                if isfield(settings, 'apiKey') && ~isempty(settings.apiKey)
                    fprintf('✓ API key found in settings file\n');
                else
                    fprintf('⚠ WARNING: No API key found in settings file\n');
                    fprintf('  Orion will run in offline debug mode\n');
                end
            catch
                fprintf('⚠ WARNING: Could not load settings file\n');
                fprintf('  Orion will run in offline debug mode\n');
            end
        else
            fprintf('⚠ WARNING: No API key found. Orion will run in offline debug mode\n');
            fprintf('  Set GEMINI_API_KEY environment variable or run llm_settings.m to configure\n');
        end
    end
catch ex
    fprintf('⚠ WARNING: Error checking API configuration: %s\n', ex.message);
    fprintf('  Orion will run in offline debug mode\n');
end

% Change to the app directory
fprintf('Changing to app directory...\n');
cd app;

% Launch the AgentChat application
fprintf('Launching AgentChat...\n');
try
    AgentChat;
    fprintf('Application closed.\n');
catch ME
    fprintf('ERROR launching application: %s\n', ME.message);
    if ~isempty(ME.stack)
        fprintf('  Error in: %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
    end
end

% Return to the original directory when done
cd ..;
