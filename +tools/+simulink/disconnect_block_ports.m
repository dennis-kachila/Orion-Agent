function result = disconnect_block_ports(lineHandle)
    % DISCONNECT_BLOCK_PORTS Delete an existing signal line
    % 
    % Input:
    %   lineHandle - Handle to the line to delete
    %
    % Output:
    %   result - Structure containing operation status
    
    try
        % Validate input
        if nargin < 1 || isempty(lineHandle)
            error('Line handle must be specified');
        end
        
        % If lineHandle is a string, try to find the line
        if ischar(lineHandle) || isstring(lineHandle)
            % The input might be a block name or port path
            % Try to find lines connected to this block or port
            try
                blockPath = char(lineHandle);
                
                % Try to get port handles
                try
                    portHandles = get_param(blockPath, 'PortHandles');
                    
                    % Get all lines connected to this block
                    allLines = [];
                    
                    % Check input ports
                    if isfield(portHandles, 'Inport')
                        for i = 1:length(portHandles.Inport)
                            lineInfo = get_param(portHandles.Inport(i), 'Line');
                            if lineInfo ~= -1
                                allLines(end+1) = lineInfo;
                            end
                        end
                    end
                    
                    % Check output ports
                    if isfield(portHandles, 'Outport')
                        for i = 1:length(portHandles.Outport)
                            lineInfo = get_param(portHandles.Outport(i), 'Line');
                            if lineInfo ~= -1
                                allLines(end+1) = lineInfo;
                            end
                        end
                    end
                    
                    if isempty(allLines)
                        error('No lines found connected to %s', blockPath);
                    end
                    
                    % If there are multiple lines, delete the first one
                    lineHandle = allLines(1);
                    fprintf('Found line handle %d connected to %s\n', lineHandle, blockPath);
                catch ME
                    error('Could not find lines for path %s: %s', blockPath, ME.message);
                end
            catch findError
                error('Invalid line handle and could not convert to line: %s', findError.message);
            end
        end
        
        % Get information about the line before deleting it
        try
            srcPort = get_param(lineHandle, 'SrcPortHandle');
            dstPort = get_param(lineHandle, 'DstPortHandle');
            
            % Get parent blocks
            srcBlock = get_param(srcPort, 'Parent');
            dstBlock = get_param(dstPort, 'Parent');
            
            srcBlockName = getfullname(srcBlock);
            dstBlockName = getfullname(dstBlock);
            
            % Get the model name
            modelName = bdroot(srcBlock);
            
            fprintf('Disconnecting line from %s to %s\n', srcBlockName, dstBlockName);
            
            % Get snapshot before disconnection
            try
                pngDataBefore = Simulink.BlockDiagram.createSnapshot(modelName);
            catch
                pngDataBefore = [];
            end
            
            % Delete the line
            delete_line(lineHandle);
            
            fprintf('Line deleted successfully\n');
            
            % Get snapshot after disconnection
            try
                pngDataAfter = Simulink.BlockDiagram.createSnapshot(modelName);
                pngBase64 = base64encode(pngDataAfter);
            catch
                pngBase64 = '';
            end
            
            % Return result
            result = struct('status', 'success', ...
                           'sourceBlock', srcBlockName, ...
                           'destinationBlock', dstBlockName, ...
                           'modelName', modelName, ...
                           'snapshot', pngBase64, ...
                           'summary', sprintf('Disconnected line from %s to %s in model %s.', srcBlockName, dstBlockName, modelName));
        catch ME
            % If we can't get line info, just try to delete it anyway
            delete_line(lineHandle);
            
            % Return a more generic result
            result = struct('status', 'success', ...
                           'message', 'Line was deleted but source/destination info could not be retrieved', ...
                           'summary', 'A signal line was deleted, but detailed connection info could not be retrieved.');
        end
        
    catch ME
        % Handle errors
        errorMsg = agent.utils.redactErrors(ME);
        result = struct('status', 'error', 'error', errorMsg, ...
                       'summary', sprintf('Failed to disconnect line: %s', errorMsg));
    end
end

function encoded = base64encode(data)
    % Simple base64 encoding for snapshot data
    import org.apache.commons.codec.binary.Base64;
    encoded = char(Base64.encodeBase64(data));
end