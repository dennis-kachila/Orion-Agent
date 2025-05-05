function result = read_file_content(fileName)
    % READ_FILE_CONTENT Read entire file into a string and return it
    % 
    % Input:
    %   fileName - Path to the file to read
    %
    % Output:
    %   result - Structure containing file content and status
    
    try
        % Use absolute path if relative path is provided
        if ~isempty(fileName) && ~ispc && fileName(1) ~= '/' || ispc && ~contains(fileName, ':')
            fileName = fullfile(pwd, fileName);
        end
        
        fprintf('Reading file: %s\n', fileName);
        
        % Check if file exists
        if ~exist(fileName, 'file')
            error('File does not exist: %s', fileName);
        end
        
        % Read file content
        fileID = fopen(fileName, 'r');
        if fileID == -1
            error('Could not open file for reading: %s', fileName);
        end
        
        % Read entire file contents
        content = '';
        try
            content = fscanf(fileID, '%c', inf);
        catch ME
            fclose(fileID);
            error('Error reading file content: %s', ME.message);
        end
        fclose(fileID);
        
        % Return result with file content
        result = struct('status', 'success', ...
                       'summary', sprintf('Read file: %s', fileName), ...
                       'fileName', fileName, ...
                       'content', content, ...
                       'byteCount', length(content));
        
        fprintf('Successfully read %d bytes from file\n', length(content));
        
    catch ME
        % Handle any errors
        errorMsg = agent.utils.redactErrors(ME);
        result = struct('status', 'error', 'error', errorMsg, ...
                       'summary', sprintf('Failed to read file: %s', errorMsg));
    end
end