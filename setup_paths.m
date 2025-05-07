% SETUP_PATHS Add all required paths to MATLAB path
% Run this script before using Orion Agent

fprintf('Setting up Orion Agent paths...\n');

% Get the root directory
rootDir = fileparts(mfilename('fullpath'));

% Clear and re-add paths to avoid conflicts
fprintf('Clearing existing paths to avoid conflicts...\n');
warning('off', 'MATLAB:rmpath:DirNotFound'); % Suppress warnings
rmpath(genpath(rootDir));
warning('on', 'MATLAB:rmpath:DirNotFound');

% Add the root directory and all subdirectories
fprintf('Adding paths...\n');
addpath(rootDir);
addpath(genpath(rootDir));

% Force rehash to ensure MATLAB recognizes the added files
rehash path;

% Display current directory and path for debugging
fprintf('Current directory: %s\n', pwd);
fprintf('Root directory: %s\n', rootDir);
fprintf('Paths added successfully!\n');

% Verify key files/packages are on the path
fprintf('\nChecking for required components...\n');

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

% Check for tools.matlab.run_code_file
try
    % Try to evaluate the function directly for a more reliable check
    test_result = tools.matlab.run_code_file(fullfile(rootDir, '+tools', '+matlab', 'test_setup.m'));
    fprintf('✓ Successfully executed tools.matlab.run_code_file function!\n');
catch ME
    fprintf('✗ Error executing tools.matlab.run_code_file: %s\n', ME.message);
    fprintf('  Looking for file at: %s\n', fullfile(rootDir, '+tools', '+matlab', 'run_code_file.m'));
end

% Ask user if they want to save the path for future sessions
if ~isdeployed && usejava('desktop')
    % Only ask for input if running in desktop mode (not batch)
    fprintf('\nWould you like to save the path for future MATLAB sessions? (y/n): ');
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
fprintf('AgentAppChat\n\n');
