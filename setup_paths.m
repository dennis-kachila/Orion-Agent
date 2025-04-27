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

if exist('tools.run_code', 'file')
    fprintf('✓ tools.run_code function found\n');
else
    fprintf('✗ tools.run_code function NOT found! Check that the +tools directory is in the path.\n');
end

% Save the path for future MATLAB sessions (optional)
fprintf('\nWould you like to save the path for future MATLAB sessions? (y/n): ');
response = input('', 's');
if strcmpi(response, 'y')
    savepath;
    fprintf('Path saved for future sessions.\n');
else
    fprintf('Path not saved. You will need to run this script again in new MATLAB sessions.\n');
end
