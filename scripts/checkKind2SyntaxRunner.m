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
function checkKind2SyntaxRunner(source, destination, options)

if nargin < 3 || isempty(options)
    options = {'nodisplay'};
end
bdclose('all')
regression_path = fullfile(source);

addpath(genpath(regression_path));
tools_config;

display_msg('Starting', Constants.INFO, 'Simulink to Lustre Regression', '');
mdl_models = dir(fullfile(regression_path,'**', '*.mdl'));
slx_models = dir(fullfile(regression_path,'**', '*.slx'));
all_models = [mdl_models; slx_models];
models_name = {all_models.name};
n = numel(models_name);
if n==0
    display_msg('No Simulink model found', Constants.RESULT, 'Runner', '');
    return;
end
if isfield(all_models, 'folder')
    models_path = arrayfun(@(x) [x.folder '/' x.name], all_models, 'UniformOutput', 0);
else
    models_path = models_name;
end
valid = zeros(n,1);
kind2_status = zeros(n,1);
is_unsupported = zeros(n,1);
is_abstracted = zeros(n,1);
%models_path = cell(1, n);
for i=1:n
    display_msg(sprintf('running file number %d from %d', i, n), ...
        MsgType.RESULT, 'Runner', '');
    bdclose('all')
    slx_full_path = which(char(models_path{i}));
    %models_path{i}= slx_full_path;
    try
        load_system(slx_full_path);
        [~, base_name, ~] = fileparts(slx_full_path);
        if bdIsLibrary(base_name)
            continue;
        end
        [lus_file_path, ~, status, unsupportedOptions, abstractedBlocks] = ...
            ToLustre(slx_full_path, [], 'KIND2', options{:});
        is_unsupported_i = ~isempty(unsupportedOptions) || status;
        is_abstracted_i = ~isempty(abstractedBlocks);
        command = sprintf('%s --z3_bin %s -xml  %s  --enable interpreter ',...
            KIND2, Z3,  lus_file_path);
        display_msg(command, ...
            MsgType.DEBUG, 'checkKind2SyntaxRunner', '');
        try
            [kind2_status_i, msg] = cmd(command, 4);
        catch
            kind2_status_i = 1;
            msg = 'TIMEOUT';
        end
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
    valid(i) = kind2_status_i == 0;
    kind2_status(i) = kind2_status_i;
    is_unsupported(i) = is_unsupported_i;
    is_abstracted(i) = is_abstracted_i;
    
    
end
bdclose('all')
result = table(models_name', valid,...
    kind2_status, is_unsupported, is_abstracted, ...
    'VariableNames', {'models_name','valid',...
    'kind2_status', 'is_unsupported', 'is_abstracted'});

% if you want to order the result by a column
result = sortrows(result,2);
% plot statistics
t = datetime('now','Format','dd-MM-yyyy''@''HHmmss');
filename = ['KIND2_regression_result_' char(t) '.csv'];
writetable(result,filename);
mv_cmd = sprintf('mv %s %s', filename, destination);
system(mv_cmd);
reportPath = fullfile(destination, filename);
%if you want to debug the invalid examples
not_valid_inexes = find(valid~=1);
if ~isempty(not_valid_inexes)
    try
        not_valid_models_dir = fullfile(regression_path, 'KIND2_not_valid_models');
        if ~exist(not_valid_models_dir, 'dir')
            mkdir(not_valid_models_dir);
        end
        t = datetime('now','Format','dd-MM-yyyy''@''HHmmss');
        report2Path = fullfile(destination, ['KIND2_not_valid_models_' char(t) '.csv']);
        fileID = fopen(report2Path,'w');
        formatSpec = '%s\n';
        for i=not_valid_inexes'
            if fileID> 0 ;fprintf(fileID,formatSpec,models_name{i});end
            src = models_path{i};
            dst = fullfile(not_valid_models_dir, char(models_name{i}));
            copyfile(src, dst);
        end
    catch ME
        display_msg(ME.message, Constants.ERROR, 'Runner', '');
        display_msg(ME.getReport(), Constants.DEBUG, 'Runner', '');
    end
end
try
    PWD = pwd;
    cd(destination)
    system(sprintf('git commit %s %s -m "regression results"', reportPath, report2Path));
    system('git push');
    cd(PWD)
catch
end
rmpath(genpath(regression_path));
end