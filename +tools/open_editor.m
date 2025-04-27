function result = open_editor(fileName, content)
    % OPEN_EDITOR Opens the MATLAB editor with the specified file
    % Wrapper around matlab.desktop.editor.openDocument
    %
    % Input:
    %   fileName - Path to the file to open in the editor
    %   content - (Optional) Content to write to the file
    %
    % Output:
    %   result - Structure containing document object and status
    
    try
        % Use absolute path if relative path is provided
        if ~isempty(fileName) && ~ispc && fileName(1) ~= '/' || ispc && ~contains(fileName, ':')
            fileName = fullfile(pwd, fileName);
        end
        
        % Print debug info
        fprintf('Creating/opening file: %s\n', fileName);
        
        % Check if file exists
        fileExists = exist(fileName, 'file');
        if fileExists
            fprintf('File exists: Yes\n');
        else
            fprintf('File exists: No\n');
        end
        
        % Create directory if needed
        [fileDir, ~, ~] = fileparts(fileName);
        if ~exist(fileDir, 'dir') && ~isempty(fileDir)
            fprintf('Creating directory: %s\n', fileDir);
            mkdir(fileDir);
        end
        
        % Write content to file if provided
        if nargin > 1 && ~isempty(content)
            fprintf('Writing content to file (length: %d)\n', length(content));
            
            % Write the content to the file
            fid = fopen(fileName, 'w');
            if fid == -1
                error('Could not open file for writing: %s (Error: %s)', fileName, ferror(fid));
            end
            
            bytesWritten = fprintf(fid, '%s', content);
            fclose(fid);
            fileExists = true;
            
            fprintf('Content written to file (%d bytes)\n', bytesWritten);
            status = 'Content written to file';
            
            % Verify file was created
            if ~exist(fileName, 'file')
                error('File was not created despite successful write operation: %s', fileName);
            end
        end
        
        % Open or create the file
        if fileExists || exist(fileName, 'file')
            fprintf('Opening existing file in editor\n');
            document = matlab.desktop.editor.openDocument(fileName);
            if nargin <= 1 || isempty(content)
                status = 'Opened existing file';
            else
                status = 'Opened file with new content';
            end
        else
            % Create an empty file and open
            fprintf('Creating empty file\n');
            fid = fopen(fileName, 'w');
            if fid == -1
                error('Could not create empty file: %s (Error: %s)', fileName, ferror(fid));
            end
            fclose(fid);
            
            % Verify file was created before trying to open
            if ~exist(fileName, 'file')
                error('Empty file was not created: %s', fileName);
            end
            
            fprintf('Opening new file in editor\n');
            document = matlab.desktop.editor.openDocument(fileName);
            status = 'Created and opened new file';
        end
        
        % Return result
        result = struct('status', 'success', ...
                       'fileName', fileName, ...
                       'documentInfo', struct('path', document.Filename, ...
                                             'editorStatus', status));
    catch ME
        % Handle errors
        fprintf('Error in open_editor: %s\n', ME.message);
        if ~isempty(ME.stack)
            fprintf('  at %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
        end
        
        % Try direct file writing as a fallback
        if nargin > 1 && ~isempty(content)
            try
                fprintf('Attempting direct file write as fallback\n');
                
                % Create a simple file with the content
                fid = fopen(fileName, 'w');
                if fid ~= -1
                    fprintf(fid, '%s', content);
                    fclose(fid);
                    fprintf('Fallback write successful\n');
                    
                    result = struct('status', 'partial_success', ...
                                   'fileName', fileName, ...
                                   'documentInfo', struct('path', fileName, ...
                                                         'editorStatus', 'File created but editor not opened'));
                    return;
                end
            catch FallbackME
                fprintf('Fallback also failed: %s\n', FallbackME.message);
            end
        end
        
        errorMsg = agent.utils.redactErrors(ME);
        result = struct('status', 'error', 'error', errorMsg);
    end
end
