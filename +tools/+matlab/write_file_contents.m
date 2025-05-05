function result = write_file_contents(fileName, content, mode)
    % WRITE_FILE_CONTENTS Write to file with specified mode
    % 
    % Inputs:
    %   fileName - Path to the file to write to
    %   content - Content to write to the file
    %   mode - (Optional) 'overwrite' (default) or 'replace_selection'
    %
    % Output:
    %   result - Structure containing status and file information
    
    try
        % Default mode
        if nargin < 3 || isempty(mode)
            mode = 'overwrite';
        end
        
        % Use absolute path if relative path is provided
        if ~isempty(fileName) && ~ispc && fileName(1) ~= '/' || ispc && ~contains(fileName, ':')
            fileName = fullfile(pwd, fileName);
        end
        
        fprintf('Writing to file: %s (Mode: %s)\n', fileName, mode);
        
        % Create directory if needed
        [fileDir, ~, ~] = fileparts(fileName);
        if ~isempty(fileDir) && ~exist(fileDir, 'dir')
            fprintf('Creating directory: %s\n', fileDir);
            [success, msg] = mkdir(fileDir);
            if ~success
                error('Failed to create directory: %s. Error: %s', fileDir, msg);
            end
        end
        
        % Handle different modes
        switch lower(mode)
            case 'overwrite'
                % Simple file overwrite
                fid = fopen(fileName, 'w');
                if fid == -1
                    error('Could not open file for writing: %s', fileName);
                end
                bytesWritten = fprintf(fid, '%s', content);
                fclose(fid);
                fprintf('File overwritten (%d bytes)\n', bytesWritten);
                
            case 'replace_selection'
                % Use MATLAB editor API to replace selected text
                try
                    % Check if file is already open in editor
                    doc = matlab.desktop.editor.getActive;
                    
                    % If not the right document or no document is open, open the file
                    if isempty(doc) || ~strcmp(doc.Filename, fileName)
                        % Try to open/create the file
                        doc = matlab.desktop.editor.openDocument(fileName);
                    end
                    
                    % Get current selection or replace all content if no selection
                    if doc.Selection.isEmpty
                        % Replace all content
                        doc.Text = content;
                        fprintf('Replaced all content in file (no selection)\n');
                    else
                        % Replace only selected text
                        doc.Selection.Text = content;
                        fprintf('Replaced selected text in file\n');
                    end
                    
                    % Save the document
                    doc.save();
                    
                catch ME
                    % If editor operation fails, fall back to direct file write
                    fprintf('Editor operation failed, falling back to file overwrite: %s\n', ME.message);
                    fid = fopen(fileName, 'w');
                    if fid == -1
                        error('Could not open file for writing: %s', fileName);
                    end
                    bytesWritten = fprintf(fid, '%s', content);
                    fclose(fid);
                    fprintf('File overwritten (%d bytes)\n', bytesWritten);
                end
                
            otherwise
                error('Unsupported write mode: %s. Use ''overwrite'' or ''replace_selection''.', mode);
        end
        
        % Return success result
        result = struct('status', 'success', ...
                       'summary', sprintf('Wrote to file: %s', fileName), ...
                       'fileName', fileName, ...
                       'bytesWritten', length(content));
        
    catch ME
        % Handle any errors
        errorMsg = agent.utils.safeRedactErrors(ME);
        result = struct('status', 'error', 'error', errorMsg, ...
                       'summary', sprintf('Failed to write to file: %s', errorMsg));
    end
end