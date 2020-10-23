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
function  addPackagePrefix(folder, ignoredFuns, passWithoutChecking)
    if nargin < 2
        ignoredFuns = {};
    end
    if nargin < 3
        passWithoutChecking = {};
    end
    matlabFiles = dir(fullfile(folder,'**', '*.m'));
    for i=1:length(matlabFiles)
        % remove extension
        [~, f_name, ~] = fileparts(matlabFiles(i).name);
        if ismember(f_name, ignoredFuns)
            continue;
        end
        f_parent = matlabFiles(i).folder;
        path_parts = regexp(f_parent, filesep, 'split');
        % keep only package path
        path_partsWithPlusAndAT = path_parts(MatlabUtils.startsWith(path_parts, '+') ...
            |MatlabUtils.startsWith(path_parts, '@'));
        % remove package and class folder prefix
        prefix_parts = regexprep(path_partsWithPlusAndAT, '^(+|@)', '');
        % create prefix
        if startsWith(path_partsWithPlusAndAT{end}, '@')
            if isequal(prefix_parts{end}, f_name)
                % case of class folder @ClassName
                path_prefix = MatlabUtils.strjoin(prefix_parts(1:end-1), '.');
            else
                continue;
            end
        else
            path_prefix = MatlabUtils.strjoin(prefix_parts, '.');
        end
        pattern = strcat('(^|[^\./\w''])', f_name, '(\.|\()');
        rep =  strcat('$1',path_prefix, '.', f_name,'$2');
        s = arrayfun(@(x) ...
            regexprepAllFiles(fullfile(x.folder, x.name), pattern, rep, f_name, passWithoutChecking), matlabFiles);
    end
end

function status = regexprepAllFiles(file, pattern, rep, fun_to_be_replaced, passWithoutChecking)
    status = 0;
    try
        fid = fopen(file, 'r');
        tline = fgetl(fid);
        tlines = cell(0,1);
        while ischar(tline)
            tlines{end+1,1} = tline;
            tline = fgetl(fid);
        end
        fclose(fid);
        new_lines = regexprep(tlines, pattern, rep);
        I = find(~strcmp(new_lines, tlines));
        II = [];
        
        if ~isempty(I)
            [~, fname, ~] = fileparts(file);
            display_msg(sprintf('File %s', fname), MsgType.RESULT, 'addPackagePrefix', '');
        end
        for i=I'
            if ~isempty(regexp(tlines{i}, '(^|\s+)function\s+', 'match')) ...
                    || ~isempty(regexp(tlines{i}, '(^|\s+)%', 'match'))...
                    || startsWith(tlines{i}, 'classdef ') ...
                    || (i>1 && startsWith(tlines{i-1}, 'function ') && endsWith(tlines{i-1}, '...'))
                %restore original line
                new_lines{i} = tlines{i};
                continue;
            end
            II(end+1) = i;
            if ismember(fun_to_be_replaced, passWithoutChecking)
                continue;
            end
            fprintf('Original format:\n %s\n', tlines{i});
            fprintf('New format:\n %s\n', new_lines{i});
            prompt = 'Is the above transformation correct? Y/N [Y]: ';
            str = input(prompt,'s');
            if ~isempty(str) && isequal(upper(str), 'N')
                %restore original line
                new_lines{i} = tlines{i};
            end
        end
        if ~isempty(II)
            fid = fopen(file, 'w+');
            fprintf(fid, '%s\n', MatlabUtils.strjoin(new_lines, '\n'));
            fclose(fid);
        end
    catch me
        fprintf(me.getReport());
        status = 1;
    end
end