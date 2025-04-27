% FIX_TOOLS_PATH Specifically fix the tools package path issue
% Run this script to diagnose and fix the tools package issue

fprintf('Diagnosing tools package issue...\n');

% Get the root directory
rootDir = fileparts(mfilename('fullpath'));
toolsDir = fullfile(rootDir, '+tools');

% Check if the directory exists
if ~exist(toolsDir, 'dir')
    fprintf('ERROR: The +tools directory does not exist at: %s\n', toolsDir);
    return;
end

% Check if the run_code.m file exists
runCodeFile = fullfile(toolsDir, 'run_code.m');
if ~exist(runCodeFile, 'file')
    fprintf('ERROR: run_code.m does not exist at: %s\n', runCodeFile);
    return;
end

fprintf('✓ +tools directory exists at: %s\n', toolsDir);
fprintf('✓ run_code.m file exists at: %s\n', runCodeFile);

% Try to manually add the tools directory to the path
addpath(rootDir);

% Check if the function can be found now
if exist('tools.run_code', 'file')
    fprintf('✓ tools.run_code function is now accessible!\n');
else
    fprintf('✗ tools.run_code function still NOT found after adding path.\n');
    
    % Try a workaround by directly checking the function
    try
        which tools.run_code
        fprintf('✓ tools.run_code can be found with "which" command.\n');
    catch ME
        fprintf('✗ Error when using "which tools.run_code": %s\n', ME.message);
    end
end

% Try to run a simple test using the function
fprintf('\nAttempting to test tools.run_code function...\n');
try
    result = tools.run_code('disp(''Hello from run_code test'')');
    fprintf('✓ Successfully ran tools.run_code! Output: %s\n', result.output);
catch ME
    fprintf('✗ Error when testing tools.run_code: %s\n', ME.message);
    
    % Try to diagnose the specific error
    if contains(ME.message, 'agent.utils.redactErrors')
        fprintf('  The error appears to be related to agent.utils.redactErrors.\n');
        fprintf('  Checking if this function exists...\n');
        
        utilsDir = fullfile(rootDir, '+agent', 'utils');
        redactFile = fullfile(utilsDir, 'redactErrors.m');
        
        if exist(redactFile, 'file')
            fprintf('  ✓ redactErrors.m file exists at: %s\n', redactFile);
        else
            fprintf('  ✗ redactErrors.m file does NOT exist at: %s\n', redactFile);
        end
    end
end

fprintf('\nTry running AgentChat.m again. If you still have issues, you may need to:\n');
fprintf('1. Restart MATLAB completely\n');
fprintf('2. Run setup_paths.m again\n');
fprintf('3. Then run AgentChat.m\n');
