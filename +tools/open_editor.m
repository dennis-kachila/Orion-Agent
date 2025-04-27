function result = open_editor(fileName)
    % OPEN_EDITOR Opens the MATLAB editor with the specified file
    % Wrapper around matlab.desktop.editor.openDocument
    %
    % Input:
    %   fileName - Path to the file to open in the editor
    %
    % Output:
    %   result - Structure containing document object and status
    
    try
        % Check if file exists
        fileExists = exist(fileName, 'file');
        
        % Open or create the file
        if fileExists
            document = matlab.desktop.editor.openDocument(fileName);
            status = 'Opened existing file';
        else
            % Create an empty file
            [fileDir, ~, ~] = fileparts(fileName);
            
            % Create directory if it doesn't exist
            if ~exist(fileDir, 'dir') && ~isempty(fileDir)
                mkdir(fileDir);
            end
            
            % Create empty file and open
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
