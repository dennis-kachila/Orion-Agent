% LAUNCH_AGENT A simple launcher for the Orion Agent application
% Run this script from the main project directory to start the application

fprintf('=== Orion Agent Launcher (Debug Mode) ===\n');
fprintf('Current directory: %s\n', pwd);

% First, set up the paths
fprintf('Setting up paths...\n');
setup_paths;

% Add compatibility layer for safeRedactErrors in case of package path issues
fprintf('Setting up compatibility layer for utilities...\n');
try
    % Check if safeRedactErrors can be resolved as a package function
    try
        testME = MException('TEST:Error', 'Test error message');
        agent.utils.safeRedactErrors(testME);
        fprintf('✓ agent.utils.safeRedactErrors is working properly\n');
    catch
        % Create a local copy as a fallback for now
        fprintf('⚠ WARNING: Cannot resolve agent.utils.safeRedactErrors, creating a local fallback\n');
        % Define the fallback function in our workspace
        safeRedactErrors = @(ME)redactErrorsLocal(ME);
        % Make it accessible globally
        assignin('base', 'safeRedactErrors', safeRedactErrors);
        fprintf('✓ Created fallback error redaction function\n');
    end
catch 
    fprintf('⚠ WARNING: Could not set up error redaction utilities\n');
end

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
    % Check if the application is already running
    if ispc
        [~, result] = system('tasklist /FI "WINDOWTITLE eq AgentAppChat"');
        if contains(result, 'AgentAppChat')
            fprintf('⚠ WARNING: AgentAppChat is already running\n');
            return;
        end
    elseif isunix
        [~, result] = system('pgrep -f AgentAppChat');  % Update to check for AgentAppChat
        if ~isempty(result)
            fprintf('⚠ WARNING: AgentAppChat is already running\n');  % Update message to indicate correct application name
            return;
        end
   
    end
    % Start the application
    app = AgentAppChat();  % Instantiate and start the application
    fprintf('Application launched successfully.\n');  % Update message to indicate successful launch
catch ME
    % Use our fallback redaction if available
    try
        if exist('safeRedactErrors', 'var')
            errorMsg = safeRedactErrors(ME);
        else
            errorMsg = ME.message;
        end
        fprintf('ERROR launching application: %s\n', errorMsg);
    catch
        fprintf('ERROR launching application: %s\n', ME.message);
        if ~isempty(ME.stack)
            fprintf('  Error in: %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
        end
    end
end

% Return to the original directory when done
cd ..;  % Ensure this line is executed after the try-catch block

% Local fallback implementation of error redaction
function errorMsg = redactErrorsLocal(ME)
    % Simple error redaction function as a fallback
    msg = ME.message;
    % Remove absolute Windows paths
    msg = regexprep(msg, '[A-Za-z]:\\[^\s\n]*', '[REDACTED_PATH]');
    % Remove OneDrive or user directory references
    msg = regexprep(msg, 'OneDrive[^\s\n]*', '[REDACTED_ONEDRIVE]');
    msg = regexprep(msg, 'Users\\[^\s\n]*', '[REDACTED_USER]');
    
    errorMsg = sprintf('Error: %s', msg);
    
    % Add a simplified stack trace
    if ~isempty(ME.stack)
        stackStr = '\nStack trace (simplified):\n';
        maxFrames = min(3, length(ME.stack));
        
        for i = 1:maxFrames
            frame = ME.stack(i);
            funcName = regexprep(frame.name, '[A-Za-z]:\\[^\s\n]*', '[REDACTED]');
            stackStr = [stackStr, sprintf('  - Function: %s, Line: %d\n', funcName, frame.line)];
        end
        
        errorMsg = [errorMsg, stackStr];
    end
end
