classdef TestAllUtils
    %TESTALLUTILS Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods(Static)
        

        
        %% KIND2_runner
        function [kind2_status_i, is_unsupported_i, is_abstracted_i] = ...
                KIND2_runner(slx_full_path, options, KIND2, Z3)
            try
                [lus_file_path, ~, status, unsupportedOptions, abstractedBlocks] = ...
                    nasa_toLustre.ToLustre(slx_full_path, [], 'KIND2', [], options{:});
                is_unsupported_i = ~isempty(unsupportedOptions) || status;
                is_abstracted_i = ~isempty(abstractedBlocks);
                [kind2_status_i, msg] = ...
                    coco_nasa_utils.Kind2Utils.checkSyntaxError`(lus_file_path, KIND2, Z3);
                display_msg(msg, Constants.DEBUG, 'Runner', '');
                if kind2_status_i == 0
                    display_msg('Your model is compatible with KIND2!', ...
                        MsgType.RESULT, 'checkKind2SyntaxRunner', '');
                else
                    display_msg('Your model is not compatible with KIND2!', ...
                        MsgType.ERROR, 'checkKind2SyntaxRunner', '');
                end
            catch ME
                display_msg(ME.message, MsgType.ERROR, 'Runner', '');
                display_msg(ME.getReport(), MsgType.ERROR, 'Runner', '');
                kind2_status_i = -1;
                is_abstracted_i = -1;
                is_unsupported_i = -1;
            end
        end
        %% MCDC runner: check MCDC syntax for lustrec and kind2
        function [kind2_status_i, is_unsupported_i, is_abstracted_i] = ...
                MCDC_runner(slx_full_path, options, KIND2, Z3)
            try
                options{end+1} = nasa_toLustre.utils.ToLustreOptions.FORCE_CODE_GEN;
                [lus_file_path, ~, status, unsupportedOptions, abstractedBlocks] = ...
                    nasa_toLustre.ToLustre(slx_full_path, [], LusBackendType.LUSTREC, ...
                    [], options{:});
                is_unsupported_i = ~isempty(unsupportedOptions) || status;
                is_abstracted_i = ~isempty(abstractedBlocks);
                [output_dir, ~, ~] = fileparts(lus_file_path);
                
                mcdc_file = LustrecUtils.generate_MCDCLustreFile(lus_file_path, output_dir);
                
                new_mcdc_file = LustrecUtils.adapt_lustre_file(mcdc_file, LusBackendType.KIND2);
                
                [kind2_status_i, msg] = ...
                    Kind2Utils2.checkSyntaxError(new_mcdc_file, KIND2, Z3);
                display_msg(msg, Constants.DEBUG, 'Runner', '');
                if kind2_status_i == 0
                    display_msg('Your model is compatible with KIND2!', ...
                        MsgType.RESULT, 'checkKind2SyntaxRunner', '');
                else
                    display_msg('Your model is not compatible with KIND2!', ...
                        MsgType.ERROR, 'checkKind2SyntaxRunner', '');
                end
            catch ME
                display_msg(ME.message, MsgType.ERROR, 'Runner', '');
                display_msg(ME.getReport(), MsgType.ERROR, 'Runner', '');
                kind2_status_i = -1;
                is_abstracted_i = -1;
                is_unsupported_i = -1;
            end
        end
        
        %% seal runner
        function [kind2_status_i, is_unsupported_i, is_abstracted_i, ...
                lustrev_failed] = ...
                seal_runner(slx_full_path, options, KIND2, Z3,...
                LUSTREV, LUCTREC_INCLUDE_DIR)
            try
                options{end+1} = nasa_toLustre.utils.ToLustreOptions.FORCE_CODE_GEN;
                [lus_file_path, ~, status, unsupportedOptions, abstractedBlocks] = ...
                    nasa_toLustre.ToLustre(slx_full_path, [], LusBackendType.LUSTREC, ...
                    CoCoBackendType.MCDC_TESTS_GEN, options{:});
                is_unsupported_i = ~isempty(unsupportedOptions) || status;
                is_abstracted_i = ~isempty(abstractedBlocks);
                [output_dir, lus_file_name, ~] = fileparts(lus_file_path);
                main_node = MatlabUtils.fileBase(lus_file_name);
                
                [seal_file, lustrev_failed] = LustrecUtils.generateLustrevSealFile(...
                    lus_file_path, output_dir, main_node, LUSTREV, LUCTREC_INCLUDE_DIR);
                
                mcdc_file = LustrecUtils.generate_MCDCLustreFile(seal_file, output_dir);
                new_mcdc_file = LustrecUtils.adapt_lustre_file(mcdc_file, LusBackendType.KIND2);
                [kind2_status_i, msg] = ...
                    Kind2Utils2.checkSyntaxError(new_mcdc_file, KIND2, Z3);
                display_msg(msg, Constants.DEBUG, 'Runner', '');
                if kind2_status_i == 0
                    display_msg('Your model is compatible with KIND2!', ...
                        MsgType.RESULT, 'checkKind2SyntaxRunner', '');
                else
                    display_msg('Your model is not compatible with KIND2!', ...
                        MsgType.ERROR, 'checkKind2SyntaxRunner', '');
                end
            catch ME
                display_msg(ME.message, MsgType.ERROR, 'Runner', '');
                display_msg(ME.getReport(), MsgType.ERROR, 'Runner', '');
                kind2_status_i = -1;
                is_abstracted_i = -1;
                is_unsupported_i = -1;
                lustrev_failed = -1;
            end
        end
    end
end

