classdef t_basic < matlab.unittest.TestCase
    % T_BASIC Basic tests for Orion Agent tools
    % Ensures that each tool works on clean MATLAB environment
    
    properties
        ModelName
    end
    
    methods(TestMethodSetup)
        function setup(testCase)
            % Setup before each test - create unique model name
            testCase.ModelName = ['test_model_', char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'))];
        end
    end
    
    methods(TestMethodTeardown)
        function teardown(testCase)
            % Cleanup after each test
            try
                if bdIsLoaded(testCase.ModelName)
                    close_system(testCase.ModelName, 0);
                end
                
                % Delete model file if created
                modelFile = [testCase.ModelName, '.slx'];
                if exist(modelFile, 'file')
                    delete(modelFile);
                end
            catch
                % Ignore cleanup errors
            end
        end
    end
    
    methods(Test)
        function testNewModel(testCase)
            % Test new_model tool
            result = tools.new_model(testCase.ModelName);
            
            % Verify model was created
            testCase.verifyTrue(bdIsLoaded(testCase.ModelName), 'Model should be loaded');
            testCase.verifyEqual(result.status, 'success', 'Status should be success');
            testCase.verifyTrue(~isempty(result.modelHandle), 'Should return valid model handle');
        end
        
        function testAddBlockSafe(testCase)
            % Test add_block_safe tool
            
            % First create a model
            tools.new_model(testCase.ModelName);
            
            % Test adding different types of blocks
            blocks = {'built-in/Sine Wave', 'built-in/Scope', 'built-in/Gain'};
            positions = {[100 100 160 130], [300 100 360 130], [200 100 260 130]};
            
            for i = 1:length(blocks)
                result = tools.add_block_safe(testCase.ModelName, blocks{i}, positions{i});
                
                % Verify block was added
                testCase.verifyEqual(result.status, 'success', 'Status should be success');
                testCase.verifyTrue(~isempty(result.blockHandle), 'Should return valid block handle');
                
                % Verify block exists in model
                blockExists = ~isempty(find_system(testCase.ModelName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'Handle', result.blockHandle));
                testCase.verifyTrue(blockExists, 'Block should exist in model');
            end
        end
        
        function testConnect(testCase)
            % Test connect tool
            
            % Create model with blocks
            tools.new_model(testCase.ModelName);
            sineResult = tools.add_block_safe(testCase.ModelName, 'built-in/Sine Wave', [100 100 160 130]);
            scopeResult = tools.add_block_safe(testCase.ModelName, 'built-in/Scope', [300 100 360 130]);
            
            % Connect blocks
            sinePath = getfullname(sineResult.blockHandle);
            scopePath = getfullname(scopeResult.blockHandle);
            
            result = tools.connect(testCase.ModelName, sinePath, scopePath);
            
            % Verify connection was made
            testCase.verifyEqual(result.status, 'success', 'Status should be success');
            testCase.verifyTrue(~isempty(result.lineHandle), 'Should return valid line handle');
        end
        
        function testArrange(testCase)
            % Test arrange tool
            
            % Create model with blocks
            tools.new_model(testCase.ModelName);
            tools.add_block_safe(testCase.ModelName, 'built-in/Sine Wave', [100 100 160 130]);
            tools.add_block_safe(testCase.ModelName, 'built-in/Scope', [300 100 360 130]);
            
            % Arrange model
            result = tools.arrange(testCase.ModelName);
            
            % Verify arrangement worked
            testCase.verifyEqual(result.status, 'success', 'Status should be success');
        end
        
        function testSimModel(testCase)
            % Test sim_model tool
            
            % Create and connect blocks
            tools.new_model(testCase.ModelName);
            sineResult = tools.add_block_safe(testCase.ModelName, 'built-in/Sine Wave', [100 100 160 130]);
            scopeResult = tools.add_block_safe(testCase.ModelName, 'built-in/Scope', [300 100 360 130]);
            
            % Connect blocks
            sinePath = getfullname(sineResult.blockHandle);
            scopePath = getfullname(scopeResult.blockHandle);
            tools.connect(testCase.ModelName, sinePath, scopePath);
            
            % Run simulation
            result = tools.sim_model(testCase.ModelName, 1);
            
            % Verify simulation ran
            testCase.verifyEqual(result.status, 'success', 'Status should be success');
        end
        
        function testRunCode(testCase)
            % Test run_code tool
            
            % Run some simple MATLAB code
            result = tools.run_code('a = 1 + 1; disp(a);');
            
            % Verify code executed
            testCase.verifyEqual(result.status, 'success', 'Status should be success');
            testCase.verifyTrue(contains(result.output, '2'), 'Output should contain the result 2');
        end
        
        function testOpenEditor(testCase)
            % Test open_editor tool
            
            % Create temporary file path
            tempFile = [tempname, '.m'];
            
            try
                % Open file in editor
                result = tools.open_editor(tempFile);
                
                % Verify file was opened
                testCase.verifyEqual(result.status, 'success', 'Status should be success');
                testCase.verifyTrue(exist(tempFile, 'file') == 2, 'File should be created');
            catch ME
                % Handle any unexpected errors during the test
                fprintf('Error in openEditor test: %s\n', ME.message);
                rethrow(ME);
            finally
                % Clean up
                if exist(tempFile, 'file')
                    delete(tempFile);
                end
            end
        end
        
        function testDocSearch(testCase)
            % Test doc_search tool
            
            % Search for a common block
            result = tools.doc_search('Sine Wave');
            
            % Verify search returned results
            testCase.verifyEqual(result.status, 'success', 'Status should be success');
        end
    end
end
