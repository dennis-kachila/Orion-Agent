function result = close_current_model(modelName, saveBeforeClose)
    % CLOSE_CURRENT_MODEL Close the current or specified Simulink model
    % 
    % Inputs:
    %   modelName - (Optional) Name of the model to close, defaults to current model
    %   saveBeforeClose - (Optional) Boolean flag to save model before closing (default: true)
    %
    % Output:
    %   result - Structure containing operation status
    
    try
        % Handle default arguments
        if nargin < 1 || isempty(modelName)
            modelName = bdroot;
            if isempty(modelName)
                % No model is open, return early
                result = struct('status', 'success', ...
                               'message', 'No model is currently open');
                return;
            end
        end
        
        % Default: save before close
        if nargin < 2 || isempty(saveBeforeClose)
            saveBeforeClose = true;
        end
        
        % Ensure the model is open
        if ~bdIsLoaded(modelName)
            result = struct('status', 'error', ...
                           'error', sprintf('Model %s is not loaded', modelName));
            return;
        end
        
        % Save model if requested
        if saveBeforeClose
            fprintf('Saving model %s before closing...\n', modelName);
            try
                save_system(modelName);
                fprintf('Model saved successfully\n');
            catch saveErr
                errorMsg = agent.utils.redactErrors(saveErr);
                fprintf('Warning: Could not save model: %s\n', errorMsg);
            end
        end
        
        % Close the model
        fprintf('Closing model %s...\n', modelName);
        close_system(modelName, 0);  % 0 means don't save again
        
        fprintf('Model closed successfully\n');
        
        % Return result
        result = struct('status', 'success', ...
                       'modelName', modelName, ...
                       'saved', saveBeforeClose);
        
    catch ME
        % Handle any errors
        errorMsg = agent.utils.redactErrors(ME);
        result = struct('status', 'error', ...
                       'error', errorMsg);
        
        fprintf('Error closing model: %s\n', errorMsg);
    end
end