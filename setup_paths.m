% SETUP_PATHS Add all required paths to MATLAB path
% Run this script before using Orion Agent

fprintf('Setting up Orion Agent paths...\n');

% Get the root directory
rootDir = fileparts(mfilename('fullpath'));

% Add the root directory and all subdirectories
addpath(rootDir);
addpath(genpath(rootDir));

% Display current directory and path for debugging
fprintf('Current directory: %s\n', pwd);
fprintf('Root directory: %s\n', rootDir);
fprintf('Paths added successfully!\n');

% Verify key files/packages are on the path
if exist('llm.promptTemplates', 'class')
    fprintf('✓ llm.promptTemplates class found\n');
else
    fprintf('✗ llm.promptTemplates class NOT found! Check that the +llm directory is in the path.\n');
    fprintf('  Looking for: %s\n', fullfile(rootDir, '+llm', 'promptTemplates.m'));
end

if exist('agent.Agent', 'class')
    fprintf('✓ agent.Agent class found\n');
else
    fprintf('✗ agent.Agent class NOT found! Check that the +agent directory is in the path.\n');
end

% Check for tools.run_code using which command instead of exist
try
    which_result = which('tools.run_code');
    if ~isempty(which_result)
        fprintf('✓ tools.run_code function found using "which" command\n');
    else
        fprintf('✗ tools.run_code function NOT found! Check that the +tools directory is in the path.\n');
    end
catch
    fprintf('✗ Error checking tools.run_code. Check that the +tools directory is in the path.\n');
end

% Check for agent.utils.redactErrors function
try
    which agent.utils.redactErrors
    fprintf('✓ agent.utils.redactErrors function found using "which" command\n');
catch
    fprintf('✗ agent.utils.redactErrors function NOT found using "which" command\n');
    fprintf('  This may cause errors when running the application.\n');
end

% Check for agent.utils.safeRedactErrors function
try
    which agent.utils.safeRedactErrors
    fprintf('✓ agent.utils.safeRedactErrors function found using "which" command\n');
catch
    fprintf('✗ agent.utils.safeRedactErrors function NOT found using "which" command\n');
    fprintf('  This may cause errors when running the application.\n');
end

% Try to actually use the function as the ultimate test
try
    test_result = tools.run_code('disp(''Path setup successful'')');
    fprintf('✓ Successfully executed tools.run_code function!\n');
catch ME
    fprintf('✗ Error executing tools.run_code: %s\n', ME.message);
end

% Ask user if they want to save the path for future sessions
if ~isdeployed && usejava('desktop')
    % Only ask for input if running in desktop mode (not batch)
    fprintf('Would you like to save the path for future MATLAB sessions? (y/n): ');
    response = input('', 's');
    
    if strcmpi(response, 'y') || strcmpi(response, 'yes')
        savepath;
        fprintf('Path saved for future sessions.\n');
    else
        fprintf('Path not saved. You will need to run setup_paths.m again in future sessions.\n');
    end
else
    % In batch mode or deployed mode, don't ask for input
    fprintf('Running in batch mode, skipping path save prompt.\n');
end

fprintf('\nNow try running the application using:\n');
fprintf('cd app\n');
fprintf('AgentChat\n\n');
