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
        fprintf('=== DEBUG START: open_or_create_file ===\n');
        fprintf('Called with fileName: "%s"\n', fileName);
        if nargin > 1
            fprintf('Content provided: %d bytes\n', length(content));
            if ~isempty(content)
                fprintf('Content snippet: "%s..."\n', content(1:min(30, length(content))));
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
                           'summary', sprintf('Opened or created file: %s', fileName), ...
                           'fileName', fileName, ...
                           'documentInfo', struct('path', document.Filename, ...
                                                 'editorStatus', editorStatus));
        catch ME
            % If editor can't be opened, return partial success
            fprintf('Warning: Could not open file in editor: %s\n', ME.message);
            result = struct('status', 'partial_success', ...
                           'summary', sprintf('Opened or created file: %s', fileName), ...
                           'fileName', fileName, ...
                           'error', ME.message);
        end
    catch ME
        % Handle any errors
        errorMsg = agent.utils.safeRedactErrors(ME);
        result = struct('status', 'error', 'error', errorMsg, ...
                       'summary', sprintf('Failed to open or create file: %s', errorMsg));
    end
end