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
        % Check if file exists
        fileExists = exist(fileName, 'file');
        
        % Create directory if needed
        [fileDir, ~, ~] = fileparts(fileName);
        if ~exist(fileDir, 'dir') && ~isempty(fileDir)
            mkdir(fileDir);
        end
        
        % Write content to file if provided
        if nargin > 1 && ~isempty(content)
            % Write the content to the file
            fid = fopen(fileName, 'w');
            if fid == -1
                error('Could not open file for writing: %s', fileName);
            end
            fprintf(fid, '%s', content);
            fclose(fid);
            fileExists = true;
            status = 'Content written to file';
        end
        
        % Open or create the file
        if fileExists
            document = matlab.desktop.editor.openDocument(fileName);
            if nargin <= 1 || isempty(content)
                status = 'Opened existing file';
            else
                status = 'Opened file with new content';
            end
        else
            % Create an empty file and open
            fid = fopen(fileName, 'w');
            fclose(fid);
            
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
        errorMsg = agent.utils.redactErrors(ME);
        result = struct('status', 'error', 'error', errorMsg);
    end
end
