function result = commit_git_repo(commitMessage, repoPath, stageAll)
    % COMMIT_GIT_REPO Stage all changes and commit with a message via system git
    % 
    % Inputs:
    %   commitMessage - Commit message
    %   repoPath - (Optional) Path to git repository, defaults to current directory
    %   stageAll - (Optional) Boolean to stage all changes, defaults to true
    %
    % Output:
    %   result - Structure containing git operation results and status
    
    try
        % Check if git is available
        [gitStatus, ~] = system('git --version');
        if gitStatus ~= 0
            error('Git is not installed or not in the system path');
        end
        
        % Set default repo path if not specified
        if nargin < 2 || isempty(repoPath)
            repoPath = pwd;
        end
        
        % Set default staging behavior
        if nargin < 3 || isempty(stageAll)
            stageAll = true;
        end
        
        % Check if path is a git repository
        currentDir = pwd;
        cd(repoPath);
        
        [gitRepoStatus, ~] = system('git rev-parse --is-inside-work-tree');
        if gitRepoStatus ~= 0
            cd(currentDir);
            error('The specified path is not a git repository: %s', repoPath);
        end
        
        fprintf('Working with git repository at: %s\n', repoPath);
        
        % Get repository status before operations
        [~, gitStatusBefore] = system('git status --short');
        
        % Stage changes if requested
        if stageAll
            fprintf('Staging all changes...\n');
            [stageStatus, stageOutput] = system('git add --all');
            if stageStatus ~= 0
                cd(currentDir);
                error('Failed to stage changes: %s', stageOutput);
            end
        end
        
        % Get status after staging
        [~, gitStatusAfterStage] = system('git status --short');
        
        % Perform the commit
        fprintf('Committing changes with message: %s\n', commitMessage);
        
        % Make sure to properly escape the commit message for shell
        escapedMessage = commitMessage;
        if ispc
            % Windows: double quotes and escape special characters
            escapedMessage = strrep(commitMessage, '"', '\"');
            commitCmd = sprintf('git commit -m "%s"', escapedMessage);
        else
            % Unix: single quotes are safer, but need to escape them inside the message
            escapedMessage = strrep(commitMessage, '''', '''''');
            commitCmd = sprintf('git commit -m ''%s''', escapedMessage);
        end
        
        [commitStatus, commitOutput] = system(commitCmd);
        
        % Get status after commit
        [~, gitStatusAfter] = system('git status --short');
        
        % Get commit hash if successful
        commitHash = '';
        if commitStatus == 0
            [~, commitHash] = system('git rev-parse HEAD');
            commitHash = strtrim(commitHash);
            fprintf('Successfully committed changes. Commit hash: %s\n', commitHash);
        else
            fprintf('Commit operation returned status %d\n', commitStatus);
        end
        
        % Return to original directory
        cd(currentDir);
        
        % Construct result
        if commitStatus == 0
            status = 'success';
        else
            status = 'error';
        end
        result = struct('status', status, ...
                       'repositoryPath', repoPath, ...
                       'statusBefore', strtrim(gitStatusBefore), ...
                       'statusAfterStage', strtrim(gitStatusAfterStage), ...
                       'statusAfter', strtrim(gitStatusAfter));
        
        if commitStatus == 0
            % Success case
            result.commitHash = commitHash;
            result.commitMessage = commitMessage;
            result.output = strtrim(commitOutput);
        else
            % Error case
            result.error = strtrim(commitOutput);
        end
        
    catch ME
        % Handle any errors
        if exist('currentDir', 'var')
            cd(currentDir); % Ensure we return to original directory
        end
        
        errorMsg = agent.utils.redactErrors(ME);
        result = struct('status', 'error', ...
                       'error', errorMsg);
        
        fprintf('Error performing git operations: %s\n', errorMsg);
    end
end