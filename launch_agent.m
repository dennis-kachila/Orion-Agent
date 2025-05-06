% LAUNCH_AGENT A simple launcher for the Orion Agent application
% Run this script from the main project directory to start the application

fprintf('=== Orion Agent Launcher (Debug Mode) ===\n');
fprintf('Current directory: %s\n', pwd);

% Check MATLAB version compatibility
matlab_version = ver('MATLAB');
fprintf('MATLAB Version: %s\n', matlab_version.Version);
version_parts = sscanf(matlab_version.Version, '%d.%d');
if version_parts(1) < 9 || (version_parts(1) == 9 && version_parts(2) < 8)
    fprintf('⚠ WARNING: Orion Agent requires MATLAB R2020a (9.8) or newer\n');
    fprintf('  Current version: %s (%s)\n', matlab_version.Version, matlab_version.Release);
    warning_response = input('Continue anyway? (y/n): ', 's');
    if ~strcmpi(warning_response, 'y')
        fprintf('Launcher aborted by user.\n');
        return;
    end
else
    fprintf('✓ MATLAB version compatible\n');
end

% First, set up the paths
fprintf('Setting up paths...\n');
setup_paths;

% Add local error redaction function for compatibility
fprintf('Setting up local error redaction utility...\n');
try
    % Create local fallback as the primary error redaction method
    fprintf('Creating local error redaction function\n');
    % Define the function in our workspace
    safeRedactErrors = @(ME)redactErrorsLocal(ME);
    % Make it accessible globally
    assignin('base', 'safeRedactErrors', safeRedactErrors);
    fprintf('✓ Created local error redaction function\n');
catch 
    fprintf('⚠ WARNING: Could not set up error redaction utilities\n');
end

% Test LLM configuration before launching
fprintf('Testing LLM configuration...\n');
try
    % Check for API keys in environment
    geminiKey = getenv('GEMINI_API_KEY');
    openaiKey = getenv('OPENAI_API_KEY');
    
    if ~isempty(geminiKey)
        fprintf('✓ Gemini API key found in environment\n');
    elseif ~isempty(openaiKey)
        fprintf('✓ OpenAI API key found in environment\n');
    else
        fprintf('⚠ WARNING: No API key found. Orion will run in offline debug mode\n');
        fprintf('  Set GEMINI_API_KEY/OPENAI_API_KEY environment variable using set_api_key.bat\n');
    end
catch ex
    fprintf('⚠ WARNING: Error checking API configuration: %s\n', ex.message);
    fprintf('  Orion will run in offline debug mode\n');
end

% Change to the app directory
fprintf('Changing to app directory...\n');
cd app;

% Launch the AgentAppChat application
fprintf('Launching AgentAppChat...\n');
try
    % Check if the app directory exists
    if ~exist('app', 'dir')
        fprintf('⚠ ERROR: App directory not found. Make sure you are running this script from the main project directory.\n');
        return;
    end
    
    % Check if the application is already running
    if ispc
        [~, result] = system('tasklist /FI "WINDOWTITLE eq AgentAppChat"');
        if contains(result, 'AgentAppChat')
            fprintf('⚠ WARNING: AgentAppChat is already running\n');
            return;
        end
    elseif ismac
        [~, result] = system('pgrep -f "MATLAB.*AgentAppChat"');
        if ~isempty(result)
            fprintf('⚠ WARNING: AgentAppChat is already running on macOS\n');
            return;
        end
    elseif isunix
        [~, result] = system('pgrep -f "MATLAB.*AgentAppChat"');
        if ~isempty(result)
            fprintf('⚠ WARNING: AgentAppChat is already running on Linux\n');
            return;
        end
    else
        fprintf('⚠ NOTE: Unable to check if application is already running on this platform\n');
    end
    % Start the application
    app = AgentAppChat();  % Instantiate and start the application
    fprintf('✓ Application launched successfully.\n');
    % Store the app instance in base workspace for reference
    assignin('base', 'agentApp', app);
catch ME
    % Use our fallback redaction if available
    try
        if exist('safeRedactErrors', 'var')
            errorMsg = safeRedactErrors(ME);
        else
            errorMsg = ME.message;
        end
        fprintf('❌ ERROR launching application: %s\n', errorMsg);
        
        % Provide troubleshooting suggestions based on error message
        if contains(lower(ME.message), 'file not found') || contains(lower(ME.message), 'no such file')
            fprintf('  → Check that all required files are in the app directory\n');
            fprintf('  → Run setup_paths.m to ensure paths are correctly configured\n');
        elseif contains(lower(ME.message), 'permission denied') || contains(lower(ME.message), 'access')
            fprintf('  → Check file permissions in the app directory\n');
        elseif contains(lower(ME.message), 'out of memory')
            fprintf('  → Close other applications to free up memory\n');
            fprintf('  → Restart MATLAB and try again\n');
        elseif contains(lower(ME.message), 'api key')
            fprintf('  → Run llm_settings.m to configure your API key\n');
        else
            fprintf('  → Try restarting MATLAB and running setup_paths.m before launching\n');
            fprintf('  → Check the MATLAB console for additional error details\n');
        end
    catch
        fprintf('❌ ERROR launching application: %s\n', ME.message);
        if ~isempty(ME.stack)
            fprintf('  Error in: %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
        end
    end
end

% Return to the original directory when done
try
    cd ..;
    fprintf('✓ Returned to main project directory\n');
catch cdErr
    fprintf('⚠ WARNING: Could not return to original directory: %s\n', cdErr.message);
end

fprintf('=== Orion Agent Launcher completed ===\n');

% Local fallback implementation of error redaction
function errorMsg = redactErrorsLocal(ME)
    % Simple error redaction function as a fallback
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
    
    errorMsg = sprintf('Error: %s', msg);
    
    % Add a simplified stack trace
    if ~isempty(ME.stack)
        stackStr = '\nStack trace (simplified):\n';
        maxFrames = min(3, length(ME.stack));
        
        for i = 1:maxFrames
            frame = ME.stack(i);
            funcName = regexprep(frame.name, '[A-Za-z]:\\[^\s\n]*', '[REDACTED]');
            % Remove package paths but keep function name
            funcName = regexprep(funcName, '.*\.([^.]+)$', '$1');
            stackStr = [stackStr, sprintf('  - Function: %s, Line: %d\n', funcName, frame.line)];
        end
        
        errorMsg = [errorMsg, stackStr];
    end
end
