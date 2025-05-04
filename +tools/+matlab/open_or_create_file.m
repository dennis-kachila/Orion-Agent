function result = open_or_create_file(fileName, content)
    % OPEN_OR_CREATE_FILE Create file if missing, then open in MATLAB Editor
    % 
    % Inputs:
    %   fileName - Path to the file to open or create
    %   content - (Optional) Initial content to write if file doesn't exist
    %
    % Output:
    %   result - Structure containing document object and status
    
    try
        % Use absolute path if relative path is provided
        if ~isempty(fileName) && ~ispc && fileName(1) ~= '/' || ispc && ~contains(fileName, ':')
            fileName = fullfile(pwd, fileName);
        end
        
        fprintf('Opening/creating file: %s\n', fileName);
        
        % Check if file exists
        fileExists = exist(fileName, 'file');
        if fileExists
            fileExistsStr = 'Yes';
        else
            fileExistsStr = 'No';
        end
        fprintf('File exists: %s\n', fileExistsStr);
        
        % Create directory if needed
        [fileDir, ~, ~] = fileparts(fileName);
        if ~isempty(fileDir) && ~exist(fileDir, 'dir')
            fprintf('Creating directory: %s\n', fileDir);
            [success, msg] = mkdir(fileDir);
            if ~success
                error('Failed to create directory: %s. Error: %s', fileDir, msg);
            end
        end
        
        % Write content if provided and file doesn't exist
        if nargin > 1 && ~isempty(content) && ~fileExists
            fprintf('Writing initial content to new file (length: %d)\n', length(content));
            
            % Write the content to the file
            fid = fopen(fileName, 'w');
            if fid == -1
                error('Could not open file for writing: %s', fileName);
            end
            
            bytesWritten = fprintf(fid, '%s', content);
            fclose(fid);
            
            fprintf('Initial content written (%d bytes)\n', bytesWritten);
            fileExists = true;
        end
        
        % Open in MATLAB editor
        try
            document = matlab.desktop.editor.openDocument(fileName);
            fprintf('File opened in MATLAB Editor\n');
            
            % Return result
            editorStatus = 'Created and opened new file';
            if fileExists
                editorStatus = 'Opened existing file';
            end
            result = struct('status', 'success', ...
                           'fileName', fileName, ...
                           'documentInfo', struct('path', document.Filename, ...
                                                 'editorStatus', editorStatus));
        catch ME
            % If editor can't be opened, return partial success
            fprintf('Warning: Could not open file in editor: %s\n', ME.message);
            result = struct('status', 'partial_success', ...
                           'fileName', fileName, ...
                           'error', ME.message);
        end
    catch ME
        % Handle any errors
        errorMsg = agent.utils.redactErrors(ME);
        result = struct('status', 'error', 'error', errorMsg);
    end
end