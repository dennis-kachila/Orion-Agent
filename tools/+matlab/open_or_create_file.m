function result = open_or_create_file(fileName, content, overwriteExisting)
    % OPEN_OR_CREATE_FILE Create file if missing, then open in MATLAB Editor
    % 
    % Inputs:
    %   fileName - Path to the file to open or create
    %   content - (Optional) Initial content to write if file doesn't exist
    %   overwriteExisting - (Optional) Boolean to overwrite content even if file exists (default: false)
    %
    % Output:
    %   result - Structure containing document object and status
    
    fprintf('*** ENTRY POINT: tools/+matlab/open_or_create_file.m CALLED ***\n');
    fprintf('*** FUNCTION PATH: %s ***\n', mfilename('fullpath'));
    fprintf('*** TIMESTAMP: %s ***\n', datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF'));
    
    % Create variable to track execution path for debugging
    debugInfo = struct('entryTime', now, 'steps', {{}});
    debugInfo.steps{end+1} = 'Function entry';
    
    % Default for overwriteExisting is false (only write if file doesn't exist)
    if nargin < 3
        overwriteExisting = false;
    end
    
    try
        debugInfo.steps{end+1} = 'Starting content processing';
        % Check for escaped backslashes in content and fix them
        if nargin > 1 && ~isempty(content)
            fprintf('Content provided: %d bytes\n', length(content));
            debugInfo.steps{end+1} = 'Content provided';
            
            if contains(content, '\\n') || contains(content, '\\t') || contains(content, '\\r')
                fprintf('Detected escaped backslashes in content, unescaping...\n');
                debugInfo.steps{end+1} = 'Unescaping backslashes';
                
                % Replace common escaped sequences
                content = strrep(content, '\\n', sprintf('\n'));
                content = strrep(content, '\\t', sprintf('\t'));
                content = strrep(content, '\\r', sprintf('\r'));
                content = strrep(content, '\\''', '''');
                content = strrep(content, '\\"', '"');
                fprintf('Unescaped content for proper line breaks\n');
            end
        else
            debugInfo.steps{end+1} = 'No content provided';
        end
    
        % Use absolute path if relative path is provided
        if ~isempty(fileName) && (~ispc && fileName(1) ~= '/') || (ispc && ~contains(fileName, ':'))
            oldFileName = fileName;
            fileName = fullfile(pwd, fileName);
            debugInfo.steps{end+1} = sprintf('Expanded relative path: %s -> %s', oldFileName, fileName);
        else
            debugInfo.steps{end+1} = 'Using absolute path';
        end
        
        fprintf('Opening/creating file: %s\n', fileName);
        
        % Check if file exists
        fileExists = exist(fileName, 'file') == 2;
        if fileExists
            fileExistsStr = 'Yes';
            debugInfo.steps{end+1} = 'File exists';
        else
            fileExistsStr = 'No';
            debugInfo.steps{end+1} = 'File does not exist';
        end
        fprintf('File exists: %s\n', fileExistsStr);
        
        % Create directory if needed
        [fileDir, ~, ~] = fileparts(fileName);
        if ~isempty(fileDir) && ~exist(fileDir, 'dir')
            fprintf('Creating directory: %s\n', fileDir);
            debugInfo.steps{end+1} = sprintf('Creating directory: %s', fileDir);
            
            [success, msg] = mkdir(fileDir);
            if ~success
                debugInfo.steps{end+1} = sprintf('Directory creation failed: %s', msg);
                error('Failed to create directory: %s. Error: %s', fileDir, msg);
            else
                debugInfo.steps{end+1} = 'Directory created successfully';
            end
        end
        
        % Write content if provided and either file doesn't exist or overwriteExisting is true
        if nargin > 1 && ~isempty(content) && (~fileExists || overwriteExisting)
            if ~fileExists
                fprintf('Writing initial content to new file (length: %d)\n', length(content));
                debugInfo.steps{end+1} = 'Writing content to new file';
            else
                fprintf('Overwriting existing file with new content (length: %d)\n', length(content));
                debugInfo.steps{end+1} = 'Overwriting existing file';
            end
            
            % Write the content to the file
            fid = fopen(fileName, 'w');
            if fid == -1
                debugInfo.steps{end+1} = 'fopen() failed with -1';
                error('Could not open file for writing: %s', fileName);
            end
            
            bytesWritten = fprintf(fid, '%s', content);
            fclose(fid);
            debugInfo.steps{end+1} = sprintf('Wrote %d bytes to file', bytesWritten);
            
            % Verify file was actually created
            if ~exist(fileName, 'file')
                debugInfo.steps{end+1} = 'File verification failed - file does not exist after write';
                error('Failed to create file: %s - File does not exist after write attempt', fileName);
            end
            
            fprintf('Content written successfully (%d bytes)\n', bytesWritten);
            fileExists = true;
        else
            debugInfo.steps{end+1} = 'No content written (content empty, no overwrite, or file exists)';
        end
        
        % Force re-check file existence
        if ~exist(fileName, 'file')
            debugInfo.steps{end+1} = 'Final file verification failed';
            fprintf('ERROR: File does not exist after handling: %s\n', fileName);
            error('File verification failed: File does not exist: %s', fileName);
        else
            debugInfo.steps{end+1} = 'File verified to exist on disk';
            fprintf('VERIFICATION: File exists on disk: %s\n', fileName);
        end
        
        % Open in MATLAB editor
        try
            document = matlab.desktop.editor.openDocument(fileName);
            fprintf('File opened in MATLAB Editor\n');
            debugInfo.steps{end+1} = 'File opened in editor';
            
            % Ensure file is saved to disk
            if document.Modified
                document.save();
                fprintf('File saved to disk via editor\n');
                debugInfo.steps{end+1} = 'File saved via editor';
            end
            
            % Return result
            editorStatus = 'Created and opened new file';
            if fileExists
                editorStatus = 'Opened existing file';
                if nargin > 1 && ~isempty(content) && overwriteExisting
                    editorStatus = 'Overwritten and opened existing file';
                end
            end
            result = struct('status', 'success', ...
                           'summary', sprintf('Opened or created file: %s', fileName), ...
                           'fileName', fileName, ...
                           'documentInfo', struct('path', document.Filename, ...
                                                 'editorStatus', editorStatus));
            debugInfo.steps{end+1} = 'Result struct created - successful case';
        catch ME
            % If editor can't be opened, return partial success
            fprintf('Warning: Could not open file in editor: %s\n', ME.message);
            debugInfo.steps{end+1} = sprintf('Editor open failed: %s', ME.message);
            
            result = struct('status', 'partial_success', ...
                           'summary', sprintf('Opened or created file: %s', fileName), ...
                           'fileName', fileName, ...
                           'error', ME.message);
            debugInfo.steps{end+1} = 'Result struct created - partial success case';
        end
    catch ME
        % Handle any errors
        fprintf('ERROR in open_or_create_file: %s\n', ME.message);
        if ~isempty(ME.stack)
            fprintf('  at %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
        end
        
        debugInfo.steps{end+1} = sprintf('Error occurred: %s', ME.message);
        if ~isempty(ME.stack)
            debugInfo.steps{end+1} = sprintf('Error at: %s line %d', ME.stack(1).name, ME.stack(1).line);
        end
        
        errorMsg = agent.utils.safeRedactErrors(ME);
        result = struct('status', 'error', 'error', errorMsg, ...
                       'summary', sprintf('Failed to open or create file: %s', errorMsg));
        debugInfo.steps{end+1} = 'Result struct created - error case';
    end
    
    % Print exit debug information
    exitTime = now;
    executionTime = (exitTime - debugInfo.entryTime) * 86400; % Convert to seconds
    
    fprintf('*** EXIT POINT: tools/+matlab/open_or_create_file.m ***\n');
    fprintf('*** EXIT STATUS: %s ***\n', result.status);
    fprintf('*** EXECUTION TIME: %.6f seconds ***\n', executionTime);
    fprintf('*** EXECUTION PATH (%d steps): ***\n', length(debugInfo.steps));
    for i = 1:length(debugInfo.steps)
        fprintf('***   Step %d: %s ***\n', i, debugInfo.steps{i});
    end
    fprintf('*** END OF FUNCTION EXECUTION ***\n');
end
