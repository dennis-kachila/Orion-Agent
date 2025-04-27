function result = add_block_safe(modelName, blockType, position)
    % ADD_BLOCK_SAFE Adds a block to the model with a unique name
    % Wrapper around add_block with safety features
    %
    % Inputs:
    %   modelName - Name of the Simulink model
    %   blockType - Type/path of block to add (e.g. 'built-in/Sine Wave')
    %   position - [x1 y1 x2 y2] position coordinates
    %
    % Output:
    %   result - Structure containing block handle and path
    
    try
        % Ensure the model is open
        if ~bdIsLoaded(modelName)
            error('Model %s is not loaded.', modelName);
        end
        
        % If blockType doesn't specify a library path, try to find it
        if ~contains(blockType, '/')
            % Try to find the block in common libraries
            libraries = {'built-in', 'simulink', 'simulink/Sources', 'simulink/Sinks', ...
                         'simulink/Discrete', 'simulink/Continuous', 'simulink/Math Operations'};
            
            found = false;
            for i = 1:length(libraries)
                lib = libraries{i};
                try
                    % Test if block exists in this library
                    testPath = [lib, '/', blockType];
                    blocks = find_system('SearchDepth', 0, 'Name', blockType);
                    if ~isempty(blocks)
                        blockType = testPath;
                        found = true;
                        break;
                    end
                catch
                    % Continue to next library
                end
            end
            
            if ~found
                % Try a more thorough search if not found in common libraries
                try
                    blocks = find_system('SearchDepth', 0, 'Name', blockType);
                    if ~isempty(blocks)
                        blockType = char(blocks(1));
                        found = true;
                    end
                catch
                    % If still not found, keep the original and let add_block handle the error
                end
            end
        end
        
        % Create a unique block name based on the block type
        baseName = blockType;
        if contains(baseName, '/')
            [~, baseName] = fileparts(baseName);
        end
        
        % Clean up the name for use as a valid block name
        baseName = regexprep(baseName, '\W', '_');
        
        % Find existing blocks with similar names to ensure uniqueness
        existingBlocks = find_system(modelName, 'RegExp', 'on', 'Name', [baseName, '.*']);
        numExisting = length(existingBlocks);
        
        % Create unique block name
        blockName = sprintf('%s/%s%d', modelName, baseName, numExisting + 1);
        
        % Add the block to the model
        if nargin < 3 || isempty(position)
            % Use default position if not specified
            position = [100 100 160 160];
        end
        
        % Add the block with position
        blockHandle = add_block(blockType, blockName, 'Position', position);
        
        % Get the block path
        blockPath = getfullname(blockHandle);
        
        % Create snapshot for visualization
        try
            pngData = Simulink.BlockDiagram.createSnapshot(modelName);
            pngBase64 = base64encode(pngData);
        catch
            pngBase64 = '';
        end
        
        % Return result
        result = struct('status', 'success', ...
                       'blockHandle', blockHandle, ...
                       'blockPath', blockPath, ...
                       'snapshot', pngBase64);
    catch ME
        % Handle errors
        errorMsg = agent.utils.redactErrors(ME);
        result = struct('status', 'error', 'error', errorMsg);
    end
end

function encoded = base64encode(data)
    % Simple base64 encoding for snapshot data
    import org.apache.commons.codec.binary.Base64;
    encoded = char(Base64.encodeBase64(data));
end
