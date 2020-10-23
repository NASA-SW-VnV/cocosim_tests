function  setFixedStep(regression_path)
    %SETFIXEDSTEP Summary of this function goes here
    %   Detailed explanation goes here
    mdl_models = dir(fullfile(regression_path,'**', '*.mdl'));
    slx_models = dir(fullfile(regression_path,'**', '*.slx'));
    all_models = [mdl_models; slx_models];
    
    if isempty(all_models)
        display_msg('No Simulink model found', Constants.RESULT, 'Runner', '');
        return;
    end
    models_name = {all_models.name};
    if isfield(all_models, 'folder')
        all_models_folder = {all_models.folder};
        models_path = arrayfun(@(i) fullfile(all_models_folder{i}, models_name{i}), (1:length(models_name)), 'UniformOutput', 0);
    else
        models_path = models_name;
    end
    n = length(models_path);
    for i=1:n
        fprintf('%d out of %d \n', i, n);
        try
            
            slx_full_path = models_path{i};
            %fprintf('Model %s \n', slx_full_path);
            [~, base_name, ~] = fileparts(slx_full_path);
            load_system(slx_full_path);
            if bdIsLibrary(base_name)
                continue;
            end
            SampleTime_pp(base_name);
            % unset already_pp flag from models without _PP suffix
            if ~endsWith(base_name, '_PP')
                hws = get_param(base_name, 'modelworkspace') ;
                if hasVariable(hws,'already_pp')
                    assignin(hws, 'already_pp', 0);
                end
            end
            save_system(base_name);
            bdclose(base_name)
        catch me
            fprintf('*****Model %s failed: %s\n', base_name, me.message);
        end
        
    end
end

