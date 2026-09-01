function report = write_ads_variables(baseCaseFile,outCaseFile,names,values)
%WRITE_ADS_VARIABLES Write selected top-level ADS variables into a TEMP CASE.
% Core module: core/write_ads_variables.m
%
% report = write_ads_variables(baseCaseFile,outCaseFile,names,values)
%
% Version: 0.2.0
%
% The source CASE is never modified.
% Every requested variable must occur exactly once as a top-level numeric
% assignment. After writing, the output file is read again and verified.

baseCaseFile = char(baseCaseFile);
outCaseFile = char(outCaseFile);
names = strtrim(string(names(:)));
values = values(:);

if ~isfile(baseCaseFile)
    error('Base CASE does not exist: %s',baseCaseFile);
end

if numel(names) ~= numel(values)
    error('names and values must have the same length.');
end

if isempty(names)
    error('No variables were supplied for writing.');
end

if any(~isfinite(values))
    error('All values written to ADS must be finite.');
end

caseText = fileread(baseCaseFile);

if isempty(caseText)
    error('Base CASE is empty.');
end

oldValues = zeros(numel(names),1);

numPattern = '[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?';

for k = 1:numel(names)

    name = char(names(k));
    escapedName = regexptranslate('escape',name);

    linePattern = ['(?m)^[ \t]*' escapedName '[ \t]*=[^\r\n]*'];

    [lineStart,lineEnd] = regexp(caseText,linePattern,'start','end');

    if isempty(lineStart)
        error('Variable "%s" was not found as a top-level assignment.',name);
    end

    if numel(lineStart) ~= 1
        error('Variable "%s" appears %d times as a top-level assignment.', ...
            name,numel(lineStart));
    end

    oldLine = caseText(lineStart:lineEnd);

    valuePattern = ['^([ \t]*' escapedName '[ \t]*=[ \t]*)(' ...
        numPattern ')(.*)$'];

    tok = regexp(oldLine,valuePattern,'tokens','once');

    if isempty(tok)
        error('Could not parse numeric assignment for variable "%s".',name);
    end

    oldValues(k) = str2double(tok{2});
    valueText = sprintf('%.15g',values(k));

    newLine = [tok{1} valueText tok{3}];

    caseText = [ ...
        caseText(1:lineStart-1) ...
        newLine ...
        caseText(lineEnd+1:end)];
end

outDir = fileparts(outCaseFile);

if ~isempty(outDir) && ~isfolder(outDir)
    mkdir(outDir);
end

fid = fopen(outCaseFile,'w');

if fid < 0
    error('Cannot create output CASE: %s',outCaseFile);
end

cleanupObj = onCleanup(@() safeClose(fid));
fwrite(fid,caseText,'char');
fclose(fid);
clear cleanupObj;

% Re-read and verify exact written values.
verifyText = fileread(outCaseFile);
verifiedValues = zeros(numel(names),1);

for k = 1:numel(names)

    name = char(names(k));
    escapedName = regexptranslate('escape',name);

    pattern = ['(?m)^[ \t]*' escapedName '[ \t]*=[ \t]*(' ...
        numPattern ')'];

    tok = regexp(verifyText,pattern,'tokens');

    if numel(tok) ~= 1
        error('Verification failed for "%s": expected one assignment.',name);
    end

    verifiedValues(k) = str2double(tok{1}{1});

    tol = 1e-12 * max(1,abs(values(k)));

    if abs(verifiedValues(k)-values(k)) > tol
        error(['Verification failed for "%s": requested %.15g, ' ...
               'read back %.15g.'],name,values(k),verifiedValues(k));
    end
end

report = struct();
report.version = '0.2.0';
report.baseCaseFile = baseCaseFile;
report.outCaseFile = outCaseFile;
report.names = names;
report.oldValues = oldValues;
report.requestedValues = values;
report.verifiedValues = verifiedValues;
report.passed = true;

end


function safeClose(fid)

if isnumeric(fid) && isscalar(fid) && fid > 0
    try
        fclose(fid);
    catch
    end
end

end
