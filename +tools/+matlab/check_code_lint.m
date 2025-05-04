function result = check_code_lint(input, isFile)
    % CHECK_CODE_LINT Run mlint/checkcode and return lint messages
    % 
    % Inputs:
    %   input - Either MATLAB code as string or path to .m file
    %   isFile - (Optional) Boolean flag, true if input is a file path
    %
    % Output:
    %   result - Structure containing lint messages and status
    
    try
        % Determine if input is code or file path
        if nargin < 2 || isempty(isFile)
            % Auto-detect if input is a file
            [~, ~, ext] = fileparts(input);
            isFile = ~isempty(ext) && strcmpi(ext, '.m') && exist(input, 'file');
        end
        
        if isFile
            fprintf('Running code linting on file: %s\n', input);
        else
            fprintf('Running code linting on provided code\n');
        end
        
        % Handle file or direct code
        if isFile
            % Input is a file path
            if ~exist(input, 'file')
                error('File does not exist: %s', input);
            end
            
            % Run checkcode/mlint on file
            [messages, id] = checkcode(input, '-struct');
            
            % Get file content for reference
            fid = fopen(input, 'r');
            if fid ~= -1
                fileContent = fscanf(fid, '%c', inf);
                fclose(fid);
            else
                fileContent = '';
                warning('Could not read file content for reference');
            end
            
            % Return result
            result = struct('status', 'success', ...
                           'source', 'file', ...
                           'fileName', input, ...
                           'messageCount', length(messages), ...
                           'messages', {messages}, ...
                           'messageIDs', {id}, ...
                           'fileContent', fileContent);
        else
            % Input is MATLAB code - write to temp file for linting
            tempFileName = fullfile(tempdir, ['temp_lint_', num2str(randi(999999)), '.m']);
            try
                % Write code to temp file
                fid = fopen(tempFileName, 'w');
                if fid == -1
                    error('Could not create temporary file for linting');
                end
                fprintf(fid, '%s', input);
                fclose(fid);
                
                % Run checkcode/mlint on temp file
                [messages, id] = checkcode(tempFileName, '-struct');
                
                % Return result
                result = struct('status', 'success', ...
                               'source', 'code', ...
                               'codeLength', length(input), ...
                               'messageCount', length(messages), ...
                               'messages', {messages}, ...
                               'messageIDs', {id}, ...
                               'code', input);
            catch ME
                % Re-throw the error
                rethrow(ME);
            finally
                % Clean up temp file
                if exist(tempFileName, 'file')
                    delete(tempFileName);
                end
            end
        end
        
        % Format messages for easier display
        formattedMessages = cell(length(messages), 1);
        for i = 1:length(messages)
            msg = messages(i);
            formattedMessages{i} = sprintf('Line %d, Col %d: %s (ID: %s)', ...
                msg.line, msg.column, msg.message, id{i});
        end
        
        % Update result with formatted messages
        result.formattedMessages = formattedMessages;
        
        fprintf('Found %d lint message(s)\n', length(messages));
        
    catch ME
        % Handle any errors
        result = struct('status', 'error', ...
                       'source', '', ...
                       'error', agent.utils.redactErrors(ME)); % Ensure semicolon to suppress output
        if isFile
            result.source = 'file';
        else
            result.source = 'code';
        end
        
        if isFile
            result.fileName = input;
        else
            result.codePreview = input(1:min(100, length(input)));
        end
    end
end