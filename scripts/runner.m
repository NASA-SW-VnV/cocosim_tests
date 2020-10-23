%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Author: Hamza Bourbouh <hamza.bourbouh@nasa.gov>
% Notices:
%
% Copyright @ 2020 United States Government as represented by the
% Administrator of the National Aeronautics and Space Administration.  All
% Rights Reserved.
%
% Disclaimers
%
% No Warranty: THE SUBJECT SOFTWARE IS PROVIDED "AS IS" WITHOUT ANY
% WARRANTY OF ANY KIND, EITHER EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING,
% BUT NOT LIMITED TO, ANY WARRANTY THAT THE SUBJECT SOFTWARE WILL CONFORM
% TO SPECIFICATIONS, ANY IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS
% FOR A PARTICULAR PURPOSE, OR FREEDOM FROM INFRINGEMENT, ANY WARRANTY THAT
% THE SUBJECT SOFTWARE WILL BE ERROR FREE, OR ANY WARRANTY THAT
% DOCUMENTATION, IF PROVIDED, WILL CONFORM TO THE SUBJECT SOFTWARE. THIS
% AGREEMENT DOES NOT, IN ANY MANNER, CONSTITUTE AN ENDORSEMENT BY
% GOVERNMENT AGENCY OR ANY PRIOR RECIPIENT OF ANY RESULTS, RESULTING
% DESIGNS, HARDWARE, SOFTWARE PRODUCTS OR ANY OTHER APPLICATIONS RESULTING
% FROM USE OF THE SUBJECT SOFTWARE.  FURTHER, GOVERNMENT AGENCY DISCLAIMS
% ALL WARRANTIES AND LIABILITIES REGARDING THIRD-PARTY SOFTWARE, IF PRESENT
% IN THE ORIGINAL SOFTWARE, AND DISTRIBUTES IT "AS IS."
%
% Waiver and Indemnity:  RECIPIENT AGREES TO WAIVE ANY AND ALL CLAIMS
% AGAINST THE UNITED STATES GOVERNMENT, ITS CONTRACTORS AND SUBCONTRACTORS,
% AS WELL AS ANY PRIOR RECIPIENT.  IF RECIPIENT'S USE OF THE SUBJECT
% SOFTWARE RESULTS IN ANY LIABILITIES, DEMANDS, DAMAGES, EXPENSES OR
% LOSSES ARISING FROM SUCH USE, INCLUDING ANY DAMAGES FROM PRODUCTS BASED
% ON, OR RESULTING FROM, RECIPIENT'S USE OF THE SUBJECT SOFTWARE, RECIPIENT
% SHALL INDEMNIFY AND HOLD HARMLESS THE UNITED STATES GOVERNMENT, ITS
% CONTRACTORS AND SUBCONTRACTORS, AS WELL AS ANY PRIOR RECIPIENT, TO THE
% EXTENT PERMITTED BY LAW.  RECIPIENT'S SOLE REMEDY FOR ANY SUCH MATTER
% SHALL BE THE IMMEDIATE, UNILATERAL TERMINATION OF THIS AGREEMENT.
%
% Notice: The accuracy and quality of the results of running CoCoSim
% directly corresponds to the quality and accuracy of the model and the
% requirements given as inputs to CoCoSim. If the models and requirements
% are incorrectly captured or incorrectly input into CoCoSim, the results
% cannot be relied upon to generate or error check software being developed.
% Simply stated, the results of CoCoSim are only as good as
% the inputs given to CoCoSim.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function runner(source, destination, backend, options, commitReport, ignore_preFailedModels)
    
    
    
    
    if nargin < 3 || isempty(backend)
        backend = coco_nasa_utils.LusBackendType.LUSTREC;
    end
    if nargin < 4 || isempty(options)
        options = {nasa_toLustre.utils.ToLustreOptions.NODISPLAY};
    end
    if nargin < 5
        commitReport = false;
    end
    if nargin < 6
        ignore_preFailedModels = false;
    end
    coco_nasa_utils.SLXUtils.bdclose()
    regression_path = fullfile(source);
    
    addpath(genpath(regression_path));
    tools_config;
    
    display_msg('Starting', Constants.INFO, 'Simulink to Lustre Regression', '');
    mdl_models = dir(fullfile(regression_path,'**', '*.mdl'));
    slx_models = dir(fullfile(regression_path,'**', '*.slx'));
    all_models = [mdl_models; slx_models];
    
    if isempty(all_models)
        display_msg('No Simulink model found', Constants.RESULT, 'Runner', '');
        return;
    end
    not_valid_folder_suffix =  '_not_valid_models';
    not_valid_models_dir = fullfile(regression_path, ...
        strcat(backend, not_valid_folder_suffix));
    
    models_name = {all_models.name};
    if isfield(all_models, 'folder')
        all_models_folder = {all_models.folder};
        if ignore_preFailedModels
            % remove not valid folder.
            I = ~endsWith(all_models_folder, not_valid_folder_suffix);
            all_models_folder = all_models_folder(I);
            models_name = models_name(I);
            % remove cocosim_output folder
            all_models_grand_parents = cellfun(@(x) fileparts(x), all_models_folder, 'UniformOutput', 0);
            I = ~endsWith(all_models_grand_parents, 'cocosim_output');
            all_models_folder = all_models_folder(I);
            models_name = models_name(I);
        end
        models_path = arrayfun(@(i) fullfile(all_models_folder{i}, models_name{i}), (1:length(models_name)), 'UniformOutput', 0);
        
    else
        if ignore_preFailedModels
            % remove not valid folder.
            all_models_parents = cellfun(@(x) fileparts(x), models_name, 'UniformOutput', 0);
            models_name = models_name(~endsWith(all_models_parents, not_valid_models_dir));
            % remove cocosim_output folder
            all_models_grand_parents = cellfun(@(x) fileparts(x), all_models_parents, 'UniformOutput', 0);
            models_name = models_name(~endsWith(all_models_grand_parents, 'cocosim_output'));
        end
        models_path = models_name;
    end
    models_path = models_path';
    n = length(models_path);
    
    
    valid = zeros(n,1);
    pp_failed = zeros(n,1);
    pp_valid = zeros(n,1);
    pp_sim_failed = zeros(n,1);
    slx2lus_failed = zeros(n,1);
    %For Lustrec
    lustrec_failed = zeros(n,1);
    lustrec_binary_failed = zeros(n,1);
    sim_failed = zeros(n,1);
    is_unsupported = zeros(n,1);
    %For lustrev
    lustrev_failed = zeros(n,1);
    %For Kind2
    kind2_status = zeros(n,1);
    is_abstracted = zeros(n,1);
    
    % cell arrays
    lus_file_path = arrayfun(@(x) '', (1:n), 'UniformOutput', 0)';
    orig_VS_pp_cex_file_path = arrayfun(@(x) '', (1:n), 'UniformOutput', 0)';
    pp_VS_lustre_cex_file_path = arrayfun(@(x) '', (1:n), 'UniformOutput', 0)';
    ir_json_path = arrayfun(@(x) '', (1:n), 'UniformOutput', 0)';
    for i=1:n
        try
            display_msg(sprintf('running file number %d out of %d', i, n), ...
                MsgType.RESULT, 'Runner', '');
            coco_nasa_utils.SLXUtils.bdclose()
            slx_full_path = models_path{i};
            
            load_system(models_path{i});
            [~, base_name, ~] = fileparts(slx_full_path);
            
            if bdIsLibrary(base_name)
                valid(i) = 1;
                continue;
            end
            if coco_nasa_utils.LusBackendType.isLUSTREC(backend)
                res = validate_ToLustre( slx_full_path, 1, [], 0, 0, [],options);
                valid(i) = res.pp_VS_lustre_valid;
                pp_valid(i) = res.orig_VS_pp_valid;
                pp_sim_failed(i) = res.orig_VS_pp_simulation_failed;
                slx2lus_failed(i) = res.ToLustre_failed;
                is_unsupported(i) = res.is_unsupported;
                lustrec_failed(i) = res.lustrec_failed;
                lustrec_binary_failed(i) = res.lustrec_binary_failed;
                sim_failed(i) = res.pp_VS_lustre_simulation_failed;
                lus_file_path{i} = res.lus_file_path;
                orig_VS_pp_cex_file_path{i} = res.orig_VS_pp_cex_file_path;
                pp_VS_lustre_cex_file_path{i} = res.pp_VS_lustre_cex_file_path;
                ir_json_path{i} = res.ir_json_path;
                if commitReport
                    if ~isempty(res.lus_file_path)
                        system(sprintf('git add -f %s', res.lus_file_path));
                    end
                    if ~isempty(res.orig_VS_pp_cex_file_path)
                        system(sprintf('git add -f %s', res.orig_VS_pp_cex_file_path));
                    end
                    if ~isempty(res.pp_VS_lustre_cex_file_path)
                        system(sprintf('git add -f %s', res.pp_VS_lustre_cex_file_path));
                    end
                    if ~isempty(res.ir_json_path)
                        system(sprintf('git add -f %s', res.ir_json_path));
                    end
                end
            elseif coco_nasa_utils.LusBackendType.isKIND2(backend)
                [kind2_status_i, is_unsupported_i, is_abstracted_i] = ...
                    TestAllUtils.KIND2_runner(slx_full_path, options, KIND2, Z3);
                valid(i) = kind2_status_i == 0;
                kind2_status(i) = kind2_status_i;
                is_unsupported(i) = is_unsupported_i;
                is_abstracted(i) = is_abstracted_i;
                
                
            elseif CoCoBackendType.isMCDCTESTSGEN(backend)
                [kind2_status_i, is_unsupported_i, is_abstracted_i] = ...
                    TestAllUtils.MCDC_runner(slx_full_path, options, KIND2, Z3);
                valid(i) = kind2_status_i == 0;
                kind2_status(i) = kind2_status_i;
                is_unsupported(i) = is_unsupported_i;
                is_abstracted(i) = is_abstracted_i;
                
            elseif CoCoBackendType.isSEALTESTSGEN(backend)
                [kind2_status_i, is_unsupported_i, is_abstracted_i, ...
                    lustrev_failed_i] = ...
                    TestAllUtils.seal_runner(slx_full_path, options, KIND2, Z3,...
                    LUSTREV, LUCTREC_INCLUDE_DIR);
                valid(i) = kind2_status_i == 0;
                kind2_status(i) = kind2_status_i;
                is_unsupported(i) = is_unsupported_i;
                is_abstracted(i) = is_abstracted_i;
                lustrev_failed(i) = lustrev_failed_i;
                
            elseif CoCoBackendType.isPPVALIDATION(backend)
                [pp_valid_i, pp_sim_failed_i, pp_failed_i] = ...
                    PP2Utils.validatePP(slx_full_path, options);
                valid(i) = pp_valid_i;
                pp_failed(i) = pp_failed_i;
                pp_valid(i) = pp_valid_i;
                pp_sim_failed(i) = pp_sim_failed_i;
                
            elseif CoCoBackendType.isCOMPATIBILITY(backend)
                [unsupportedOptions, status, ~,  ~, ~, abstractedBlocks] = ...
                    nasa_toLustre.ToLustreUnsupportedBlocks(slx_full_path, ...
                    [], coco_nasa_utils.LusBackendType.KIND2, [], options);
                valid(i) = isempty(unsupportedOptions) && status == 0;
                is_unsupported(i) = ~isempty(unsupportedOptions);
                is_abstracted(i) = ~isempty(abstractedBlocks);
                
            elseif CoCoBackendType.isGUIDELINES(backend)
                [~, status] = check_guidelines(slx_full_path, 'nodisplay');
                valid(i) =  status == 0;
            else
                error('UNKNOWN BACKEND %s', backend);
            end
            
        catch ME
            display_msg(ME.message, Constants.ERROR, 'Runner', '');
            display_msg(ME.getReport(), Constants.ERROR, 'Runner', '');
            coco_nasa_utils.SLXUtils.terminate(base_name);
            %continue;
        end    
        try
            coco_nasa_utils.SLXUtils.bdclose()
        catch
            coco_nasa_utils.SLXUtils.terminate(base_name);
            coco_nasa_utils.SLXUtils.terminate(strcat(base_name, '_PP'));
        end
    end
    
    % In the case of ctrl+c,
    % TODO: results are saved twice if no user termination happened.
    %cleanupObj = onCleanup(@() ...
        save_report(regression_path, backend, destination, not_valid_models_dir, ...
        commitReport, models_name, models_path, valid, pp_failed, pp_valid, pp_sim_failed,...
        slx2lus_failed, kind2_status,...
        lustrec_failed, lustrec_binary_failed, sim_failed, ...
        is_unsupported, is_abstracted, lustrev_failed, ...
        lus_file_path, ir_json_path, ...
        orig_VS_pp_cex_file_path, pp_VS_lustre_cex_file_path) %);
end







%%
function save_report(regression_path, backend, destination, not_valid_models_dir, ...
        commitReport, models_name, models_path, valid, pp_failed, pp_valid, pp_sim_failed,...
        slx2lus_failed, kind2_status,...
        lustrec_failed, lustrec_binary_failed, sim_failed, ...
        is_unsupported, is_abstracted, lustrev_failed, ...
        lus_file_path, ir_json_path, ...
        orig_VS_pp_cex_file_path, pp_VS_lustre_cex_file_path)
    if coco_nasa_utils.LusBackendType.isLUSTREC(backend)
        result = table(models_name', valid, pp_valid, pp_sim_failed,...
            slx2lus_failed, is_unsupported,...
            lustrec_failed, lustrec_binary_failed, sim_failed, models_path, ...
            lus_file_path, ir_json_path, ...
            orig_VS_pp_cex_file_path, pp_VS_lustre_cex_file_path, ...
            'VariableNames', {'models_name','PP_vs_Lustre_valid',...
            'Orig_vs_PP_valid', 'Orig_vs_PP_simulation_failed',...
            'PP_to_Lustre_generation_failed', ...
            'is_unsupported', 'lustrec_to_C_code_failed',...
            'C_binary_failed', 'PP_vs_Lustre_simulation_failed', 'models_path', ...
            'lustre_file_path', 'IR_path', ...
            'Orig_vs_PP_CEX_path', 'PP_vs_Lustre_CEX_path'});
        result = sortrows(result,3);
        
    elseif coco_nasa_utils.LusBackendType.isKIND2(backend)
        result = table(models_name', valid,...
            kind2_status, is_unsupported, is_abstracted, models_path, ...
            'VariableNames', {'models_name','valid',...
            'kind2_status', 'is_unsupported', 'is_abstracted', 'models_path'});
        
    elseif CoCoBackendType.isMCDCTESTSGEN(backend)
        result = table(models_name', valid,...
            kind2_status, is_unsupported, is_abstracted, models_path, ...
            'VariableNames', {'models_name','valid',...
            'kind2_status', 'is_unsupported', 'is_abstracted', 'models_path'});
        
    elseif CoCoBackendType.isSEALTESTSGEN(backend)
        result = table(models_name', valid,...
            kind2_status, is_unsupported, is_abstracted, lustrev_failed, ...
            models_path, ...
            'VariableNames', {'models_name','valid',...
            'kind2_status', 'is_unsupported', 'is_abstracted', 'lustrev_failed', ...
            'models_path'});
        
    elseif CoCoBackendType.isPPVALIDATION(backend)
        result = table(models_name', pp_valid, pp_failed, pp_sim_failed, models_path, ...
            'VariableNames', {'models_name', 'pp_valid', 'cocosim_pp_failed', 'pp_sim_failed', 'models_path'});
        
    elseif CoCoBackendType.isCOMPATIBILITY(backend)
        result = table(models_name', valid, is_unsupported, is_abstracted, models_path, ...
            'VariableNames', {'models_name','valid', 'is_unsupported', ...
            'is_abstracted', 'models_path'});
        
    elseif isequal(backend, 'CHECK_GUIDELINES')
        result = table(models_name', valid, models_path, ...
            'VariableNames', {'models_name','valid', 'models_path'});
    end
    % if you want to order the result by a column
    result = sortrows(result,2);
    % plot statistics
    t = datetime('now','Format','dd-MM-yyyy''@''HHmmss');
    filename = [backend '_regression_result_' char(t) '.csv'];
    writetable(result,filename);
    mv_cmd = sprintf('mv %s %s', filename, destination);
    system(mv_cmd);
    reportPath = fullfile(destination, filename);
    report2Path = '';
    %if you want to debug the invalid examples
    not_valid_inexes = find(valid~=1);
    if ~isempty(not_valid_inexes)
        try
            
            %             if exist(not_valid_models_dir, 'dir')
            %                 rmdir(not_valid_models_dir, 's');
            %             end
            if ~exist(not_valid_models_dir, 'dir')
                mkdir(not_valid_models_dir);
            end
            t = datetime('now','Format','dd-MM-yyyy''@''HHmmss');
            report2Path = fullfile(destination, ['not_valid_models_' char(t) '.csv']);
            fileID = fopen(report2Path,'w');
            formatSpec = '%s\n';
            for i=not_valid_inexes'
                if fileID> 0 ;fprintf(fileID,formatSpec,models_name{i});end
                src = char(models_path{i});
                dst = fullfile(not_valid_models_dir, char(models_name{i}));
                try
                    copyfile(src, dst);
                catch
                end
            end
        catch ME
            display_msg(ME.message, Constants.ERROR, 'Runner', '');
            display_msg(ME.getReport(), Constants.DEBUG, 'Runner', '');
        end
    end
    if commitReport
        try
            PWD = pwd;
            cd(destination)
            system(sprintf('git config --local http.sslverify false'));
            if ~isempty(not_valid_inexes)
                system(sprintf('git add -f %s %s', reportPath, report2Path));
                system(sprintf('git add -f %s/*.slx', not_valid_models_dir));
                system(sprintf('git add -f %s/*.mdl', not_valid_models_dir));
                %system(sprintf('git commit -a -m "regression results"'));
            else
                system(sprintf('git add -f %s ', reportPath));
                %system(sprintf('git commit %s -m "regression results"', reportPath));
            end
            % add everyone
            system(sprintf('git commit -a -m "regression results"'));
            %system('git push');
            cd(PWD)
        catch ME
            display_msg(ME.message, Constants.ERROR, 'Runner', '');
            display_msg(ME.getReport(), Constants.DEBUG, 'Runner', '');
        end
    end
    rmpath(genpath(regression_path));
end