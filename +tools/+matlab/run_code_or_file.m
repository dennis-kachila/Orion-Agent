function result = run_code_or_file(input, isFile)
    % RUN_CODE_OR_FILE Execute inline MATLAB code OR run a named .m file
    % 
    % Inputs:
    %   input - Either MATLAB code as string or path to .m file
    %   isFile - (Optional) Boolean flag, true if input is a file path
    %
    % Output:
    %   result - Structure containing execution output and status
    
    try
        % Determine if input is code or file path
        if nargin < 2 || isempty(isFile)
            % Auto-detect if input is a file
            [~, ~, ext] = fileparts(input);
            isFile = ~isempty(ext) && strcmpi(ext, '.m') && exist(input, 'file');
        end
        
        % Handle file or direct code
        if isFile
            % Input is a file path
            if ~exist(input, 'file')
                error('File does not exist: %s', input);
            end
            
            fprintf('Running MATLAB file: %s\n', input);
            
            % Capture output from file execution
            commandStr = sprintf('run(''%s'')', input);
            output = evalc(commandStr);
            
            % Return result
            result = struct('status', 'success', ...
                           'source', 'file', ...
                           'fileName', input, ...
                           'output', output);
        else
            % Input is MATLAB code
            fprintf('Executing MATLAB code (length: %d bytes)\n', length(input));
            
            % Capture output from code execution
            output = evalc(input);
            
            % Return result
            result = struct('status', 'success', ...
                           'source', 'code', ...
                           'codeLength', length(input), ...
                           'output', output);
        end
        
        fprintf('Code execution completed successfully\n');
        
    catch ME
        % Handle any errors
        errorMsg = agent.utils.redactErrors(ME);
        result = struct('status', 'error', ...
                       'source', isFile ? 'file' : 'code', ...
                       'error', errorMsg);
        
        if isFile
            result.fileName = input;
        else
            result.codePreview = input(1:min(100, length(input)));
        end
    end
end