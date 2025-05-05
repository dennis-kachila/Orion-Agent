function result = insert_library_block(destSystem, sourceBlock, position, blockName, params)
    % INSERT_LIBRARY_BLOCK Insert a block from a library into a model
    % 
    % Inputs:
    %   destSystem - Destination system path where block will be inserted
    %   sourceBlock - Source block path from library (e.g., 'simulink/Sources/Constant')
    %   position - [Optional] 4-element vector [left top right bottom] for positioning
    %   blockName - [Optional] Name for the new block
    %   params - [Optional] Structure of parameter name/value pairs to set
    %
    % Output:
    %   result - Structure containing new block handle and path
    
    try
        % Validate inputs
        if nargin < 2
            error('Destination system and source block must be specified');
        end
        
        % Extract model name and verify it's open
        if contains(destSystem, '/')
            parts = strsplit(destSystem, '/');
            modelName = parts{1};
        else
            modelName = destSystem;
        end
        
        if ~bdIsLoaded(modelName)
            error('Model %s is not loaded', modelName);
        end
        
        % Define default position if not provided
        if nargin < 3 || isempty(position)
            % Find a suitable position if not specified
            try
                % Get all blocks in the system
                existingBlocks = find_system(destSystem, 'SearchDepth', 1);
                existingBlocks = existingBlocks(2:end); % Skip the system itself
                
                if ~isempty(existingBlocks)
                    % Find the rightmost block
                    maxRight = -Inf;
                    for i = 1:length(existingBlocks)
                        blockPos = get_param(existingBlocks{i}, 'Position');
                        maxRight = max(maxRight, blockPos(3));
                    end
                    
                    % Place new block to the right
                    position = [maxRight + 50, 100, maxRight + 150, 150];
                else
                    % Default position if no blocks exist
                    position = [100, 100, 200, 150];
                end
            catch
                % Fallback default position
                position = [100, 100, 200, 150];
            end
        end
        
        % If position is not a 4-element vector, error
        if length(position) ~= 4
            error('Position must be a 4-element vector [left top right bottom]');
        end
        
        % Generate a block name if not provided
        if nargin < 4 || isempty(blockName)
            % Extract name from source path
            [~, sourceName] = fileparts(sourceBlock);
            blockName = sourceName;
            
            % Make it unique
            counter = 1;
            while exist([destSystem '/' blockName], 'block') == 4
                blockName = sprintf('%s%d', sourceName, counter);
                counter = counter + 1;
            end
        end
        
        % Create the complete path for the new block
        newBlockPath = [destSystem '/' blockName];
        
        fprintf('Inserting block %s from %s...\n', blockName, sourceBlock);
        
        % Add the block from library
        newBlockHandle = add_block(sourceBlock, newBlockPath, 'Position', position);
        
        % Set parameters if provided
        if nargin >= 5 && ~isempty(params) && isstruct(params)
            paramFields = fieldnames(params);
            for i = 1:length(paramFields)
                paramName = paramFields{i};
                paramValue = params.(paramName);
                
                % Handle special cases for parameter types
                if isnumeric(paramValue)
                    % Convert to string if needed
                    if isscalar(paramValue)
                        paramValue = num2str(paramValue);
                    else
                        paramValue = mat2str(paramValue);
                    end
                elseif islogical(paramValue)
                    % Convert to 'on'/'off'
                    if paramValue
                        paramValue = 'on';
                    else
                        paramValue = 'off';
                    end
                elseif isstring(paramValue)
                    % Convert MATLAB string to char
                    paramValue = char(paramValue);
                end
                
                % Set the parameter
                fprintf('  Setting parameter %s = %s\n', paramName, paramValue);
                set_param(newBlockPath, paramName, paramValue);
            end
        end
        
        fprintf('Block inserted successfully\n');
        
        % Get a snapshot of the model after insertion
        try
            pngData = Simulink.BlockDiagram.createSnapshot(modelName);
            pngBase64 = base64encode(pngData);
        catch
            pngBase64 = '';
        end
        
        % Return result
        result = struct('status', 'success', ...
                       'summary', sprintf('Inserted block %s from %s into %s.', blockName, sourceBlock, destSystem), ...
                       'blockPath', newBlockPath, ...
                       'blockHandle', newBlockHandle, ...
                       'modelName', modelName, ...
                       'snapshot', pngBase64);
        
        % Add parameter info if provided
        if nargin >= 5 && ~isempty(params)
            result.setParameters = params;
        end
        
    catch ME
        % Handle any errors
        errorMsg = agent.utils.safeRedactErrors(ME);
        % Enhance user-facing error message
        errorMsg = sprintf('An error occurred: %s\nIf this persists, please check your input or contact support.', errorMsg);
        result = struct('status', 'error', 'error', errorMsg, ...
                       'summary', sprintf('Failed to insert block: %s', errorMsg));
        
        fprintf('Error inserting library block: %s\n', errorMsg);
    end
end

function encoded = base64encode(data)
    % Simple base64 encoding
    import org.apache.commons.codec.binary.Base64;
    encoded = char(Base64.encodeBase64(data));
end