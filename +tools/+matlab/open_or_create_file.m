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
    
    fprintf('*** ENTRY POINT: +tools/+matlab/open_or_create_file.m CALLED ***\n');
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
        fprintf('=== DEBUG START: open_or_create_file ===\n');
        fprintf('Called with fileName: "%s"\n', fileName);
        debugInfo.steps{end+1} = 'Debug start logged';
        if nargin > 1
            fprintf('Content provided: %d bytes\n', length(content));
            if ~isempty(content)
                fprintf('Content snippet: "%s..."\n', content(1:min(30, length(content))));
            end
            fprintf('Overwrite existing: %s\n', mat2str(overwriteExisting));
            
            % Check for escaped backslashes in content and fix them
            if contains(content, '\\n') || contains(content, '\\t') || contains(content, '\\r')
                fprintf('Detected escaped backslashes in content, unescaping...\n');
                % Replace common escaped sequences
                content = strrep(content, '\\n', newline);
                content = strrep(content, '\\t', sprintf('\t'));
                content = strrep(content, '\\r', sprintf('\r'));
                content = strrep(content, '\\''', '''');
                content = strrep(content, '\\"', '"');
                fprintf('Unescaped content snippet: "%s..."\n', content(1:min(30, length(content))));
            end
        else
            fprintf('No content provided (nargin = %d)\n', nargin);
        end
        
        % Use more robust path handling for relative paths
        if ~isempty(fileName) && (~ispc && fileName(1) ~= '/' || ispc && ~contains(fileName, ':'))
            % Check if this is a path that should go to the workspace folder
            if ~contains(fileName, filesep) || (ispc && ~contains(fileName, '\'))
                fprintf('DEBUG: Simple filename detected without path - will place in workspace folder\n');
                
                % This is likely just a filename without a path, put it in the workspace folder
                % Get the project root directory using the module location
                thisFile = mfilename('fullpath');
                fprintf('DEBUG: This function path: %s\n', thisFile);
                
                thisFolder = fileparts(thisFile);
                moduleFolder = fileparts(thisFolder); % tools/+matlab folder
                toolsFolder = fileparts(moduleFolder); % tools folder
                projectRoot = fileparts(toolsFolder);  % project root folder
                fprintf('DEBUG: Project root resolved to: %s\n', projectRoot);
                
                % Use the orion_workspace folder
                workspaceFolder = fullfile(projectRoot, 'orion_workspace');
                fprintf('DEBUG: Using workspace folder: %s\n', workspaceFolder);
                
                if ~exist(workspaceFolder, 'dir')
                    fprintf("DEBUG: Workspace folder doesn't exist, creating it\n");
                    [mkSuccess, mkMsg] = mkdir(workspaceFolder);
                    if mkSuccess
                        fprintf('Created workspace folder: %s\n', workspaceFolder);
                    else
                        fprintf('ERROR: Failed to create workspace folder: %s\n', mkMsg);
                    end
                end
                
                fileName = fullfile(workspaceFolder, fileName);
                fprintf('DEBUG: Expanded filename to: %s\n', fileName);
            else
                % This is a relative path with directories, use standard behavior
                oldFileName = fileName;
                fileName = fullfile(pwd, fileName);
                fprintf('DEBUG: Relative path detected, expanded from "%s" to "%s"\n', oldFileName, fileName);
            end
        else
            fprintf('DEBUG: Using provided absolute path: %s\n', fileName);
        end
        
        fprintf('Opening/creating file: %s\n', fileName);
        
        % Check if file exists
        fileExists = exist(fileName, 'file');
        if fileExists > 0
            fileExistsStr = 'Yes';
        else
            fileExistsStr = 'No';
        end
        fprintf('File exists: %s (return value: %d)\n', fileExistsStr, fileExists);
        
        % Create directory if needed
        [fileDir, filePart, fileExt] = fileparts(fileName);
        fprintf('DEBUG: File parts - Dir: "%s", Name: "%s", Ext: "%s"\n', fileDir, filePart, fileExt);
        
        if ~isempty(fileDir) && ~exist(fileDir, 'dir')
            fprintf('Creating directory: %s\n', fileDir);
            [success, msg] = mkdir(fileDir);
            if ~success
                fprintf('ERROR: Failed to create directory: %s. Error: %s\n', fileDir, msg);
                error('Failed to create directory: %s. Error: %s', fileDir, msg);
            else
                fprintf('DEBUG: Directory created successfully\n');
            end
        else
            if isempty(fileDir)
                fprintf('DEBUG: No directory part in path\n');
            else
                fprintf('DEBUG: Directory already exists: %s\n', fileDir);
            end
        end
        
        % Write content if provided and either file doesn't exist or overwriteExisting is true
        if nargin > 1 && ~isempty(content) && (~fileExists || overwriteExisting)
            if ~fileExists
                fprintf('Writing initial content to new file (length: %d)\n', length(content));
            else
                fprintf('Overwriting existing file with new content (length: %d)\n', length(content));
            end
            
            % Write the content to the file
            fid = fopen(fileName, 'w');
            if fid == -1
                error('Could not open file for writing: %s', fileName);
            end
            
            bytesWritten = fprintf(fid, '%s', content);
            fclose(fid);
            
            % Verify file was actually created
            if ~exist(fileName, 'file')
                error('Failed to create file: %s - File does not exist after write attempt', fileName);
            end
            
            fprintf('Content written successfully (%d bytes)\n', bytesWritten);
            fileExists = true;
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
    
    fprintf('*** EXIT POINT: +tools/+matlab/open_or_create_file.m ***\n');
    fprintf('*** EXIT STATUS: %s ***\n', result.status);
    fprintf('*** EXECUTION TIME: %.6f seconds ***\n', executionTime);
    fprintf('*** EXECUTION PATH (%d steps): ***\n', length(debugInfo.steps));
    for i = 1:length(debugInfo.steps)
        fprintf('***   Step %d: %s ***\n', i, debugInfo.steps{i});
    end
    fprintf('*** END OF FUNCTION EXECUTION ***\n');
end