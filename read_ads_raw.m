function raw = read_ads_raw(rawFile)
%READ_ADS_RAW Read ADS/Nutmeg RAW files into MATLAB.
% Generic RAW Parser v0.5.1
%
% raw = read_ads_raw(rawFile)
%
% Supports binary Nutmeg RAW with multiple plots, real/complex data.
% The original RAW file is never modified.

if nargin < 1 || isempty(rawFile)
    [f,p] = uigetfile({'*.raw;*.*','ADS / Nutmeg RAW files'}, ...
        'Select ADS RAW File');
    if isequal(f,0)
        error('RAW file selection cancelled.');
    end
    rawFile = fullfile(p,f);
end

rawFile = char(rawFile);

if ~isfile(rawFile)
    error('RAW file does not exist: %s',rawFile);
end

fid = fopen(rawFile,'rb');
if fid < 0
    error('Cannot open RAW file: %s',rawFile);
end
bytes = fread(fid,inf,'*uint8').';
fclose(fid);

if isempty(bytes)
    error('RAW file is empty.');
end

raw = struct();
raw.version = '0.5.1';
raw.file = rawFile;
raw.fileBytes = numel(bytes);
raw.plots = struct([]);
raw.plotCount = 0;

cursor = 1;
fileLen = numel(bytes);
plotIndex = 0;
titleMarker = uint8('Title:');
binaryMarker = uint8('Binary:');
valuesMarker = uint8('Values:');

while cursor <= fileLen

    while cursor <= fileLen
        c = bytes(cursor);
        if c == 0 || c == 9 || c == 10 || c == 13 || c == 32
            cursor = cursor + 1;
        else
            break;
        end
    end

    if cursor > fileLen
        break;
    end

    relTitle = strfind(bytes(cursor:end),titleMarker);
    if isempty(relTitle)
        break;
    end

    plotStart = cursor + relTitle(1) - 1;

    relBinary = strfind(bytes(plotStart:end),binaryMarker);
    relValues = strfind(bytes(plotStart:end),valuesMarker);

    if isempty(relBinary) && isempty(relValues)
        error('Plot header found but neither Binary: nor Values: was found.');
    end

    if isempty(relBinary)
        binaryPos = inf;
    else
        binaryPos = plotStart + relBinary(1) - 1;
    end

    if isempty(relValues)
        valuesPos = inf;
    else
        valuesPos = plotStart + relValues(1) - 1;
    end

    if binaryPos < valuesPos
        mode = 'Binary';
        dataMarkerPos = binaryPos;
        markerLen = numel(binaryMarker);
    else
        mode = 'ASCII Values';
        dataMarkerPos = valuesPos;
        markerLen = numel(valuesMarker);
    end

    header = char(bytes(plotStart:dataMarkerPos-1));
    header(header == char(0)) = ' ';

    P = parseHeader(header);
    P.mode = mode;
    P.header = header;
    P.variables = parseVariables(header,P.nVariables);
    P.values = [];

    dataStart = dataMarkerPos + markerLen;

    while dataStart <= fileLen
        c = bytes(dataStart);
        if c == 10 || c == 13
            dataStart = dataStart + 1;
        else
            break;
        end
    end

    if strcmp(mode,'Binary')

        if isnan(P.nVariables) || isnan(P.nPoints)
            error('Binary RAW plot is missing variable/point counts.');
        end

        if P.isComplex
            stride = 2;
        else
            stride = 1;
        end

        payloadBytes = P.nPoints * P.nVariables * stride * 8;
        dataEnd = dataStart + payloadBytes - 1;

        if dataEnd > fileLen
            error('RAW payload shorter than expected for plot "%s".',P.plotName);
        end

        payload = bytes(dataStart:dataEnd);
        d = typecast(uint8(payload),'double');

        M = reshape(d,stride*P.nVariables,P.nPoints).';

        if P.isComplex
            P.values = complex(M(:,1:2:end),M(:,2:2:end));
        else
            P.values = M;
        end

        nextCursor = dataEnd + 1;

    else

        relNextTitle = strfind(bytes(dataStart:end),titleMarker);

        if isempty(relNextTitle)
            asciiEnd = fileLen;
            nextCursor = fileLen + 1;
        else
            asciiEnd = dataStart + relNextTitle(1) - 2;
            nextCursor = asciiEnd + 1;
        end

        asciiText = char(bytes(dataStart:asciiEnd));
        P.values = parseAsciiValues(asciiText,P.nPoints,P.nVariables,P.isComplex);

    end

    plotIndex = plotIndex + 1;

    if plotIndex == 1
        raw.plots = P;
    else
        raw.plots(plotIndex) = P; %#ok<AGROW>
    end

    cursor = nextCursor;
end

raw.plotCount = plotIndex;

if raw.plotCount == 0
    error('No Nutmeg plots were recognized in RAW file: %s',rawFile);
end

fprintf('\n============================================================\n');
fprintf(' ADS RAW PARSER RESULT\n');
fprintf('============================================================\n');
fprintf('File  : %s\n',rawFile);
fprintf('Plots : %d\n',raw.plotCount);

for k = 1:raw.plotCount
    P = raw.plots(k);
    fprintf('\n[%d] %s\n',k,P.plotName);
    fprintf('    Mode      : %s\n',P.mode);
    fprintf('    Flags     : %s\n',P.flags);
    fprintf('    Variables : %d\n',P.nVariables);
    fprintf('    Points    : %d\n',P.nPoints);
end

fprintf('============================================================\n');

end


function P = parseHeader(header)

P = struct();
P.title = getHeaderText(header,'Title');
P.date = getHeaderText(header,'Date');
P.plotName = getHeaderText(header,'Plotname');
P.flags = getHeaderText(header,'Flags');

tok = regexp(header,'No\.\s*Variables:\s*(\d+)','tokens','once');
if isempty(tok)
    P.nVariables = NaN;
else
    P.nVariables = str2double(tok{1});
end

tok = regexp(header,'No\.\s*Points:\s*(\d+)','tokens','once');
if isempty(tok)
    P.nPoints = NaN;
else
    P.nPoints = str2double(tok{1});
end

P.isComplex = contains(lower(P.flags),'complex');

end


function value = getHeaderText(header,key)

pattern = ['(?m)^' regexptranslate('escape',key) ':\s*(.*?)\s*$'];
tok = regexp(header,pattern,'tokens','once');

if isempty(tok)
    value = '';
else
    value = strtrim(tok{1});
end

end


function vars = parseVariables(header,nVariables)

vars = struct('index',{},'name',{},'type',{});

tokens = regexp(header, ...
    '(?m)(?:^Variables:\s*|^[ \t]*)(\d+)[ \t]+(\S+)[ \t]+([^\r\n]+)', ...
    'tokens');

for k = 1:numel(tokens)

    idx = str2double(tokens{k}{1});

    if isnan(idx)
        continue;
    end

    if ~isnan(nVariables)
        if idx < 0 || idx >= nVariables
            continue;
        end
    end

    duplicate = false;
    for j = 1:numel(vars)
        if vars(j).index == idx
            duplicate = true;
            break;
        end
    end

    if duplicate
        continue;
    end

    v.index = idx;
    v.name = strtrim(tokens{k}{2});
    v.type = strtrim(tokens{k}{3});
    vars(end+1) = v; %#ok<AGROW>
end

if ~isempty(vars)
    [~,ord] = sort([vars.index]);
    vars = vars(ord);
end

end


function V = parseAsciiValues(text,nPoints,nVariables,isComplex)

if isnan(nPoints) || isnan(nVariables)
    error('ASCII RAW plot is missing variable/point counts.');
end

if isComplex

    pairs = regexp(text, ...
        '\(?\s*([-+0-9.eE]+)\s*,\s*([-+0-9.eE]+)\s*\)?', ...
        'tokens');

    needed = nPoints*nVariables;

    if numel(pairs) < needed
        error('ASCII complex RAW contains fewer values than expected.');
    end

    flat = complex(zeros(needed,1));

    for k = 1:needed
        flat(k) = complex(str2double(pairs{k}{1}),str2double(pairs{k}{2}));
    end

    V = reshape(flat,nVariables,nPoints).';

else

    nums = regexp(text, ...
        '[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?', ...
        'match');

    values = str2double(nums);

    if numel(values) >= (nVariables+1)*nPoints
        temp = reshape(values(1:(nVariables+1)*nPoints), ...
            nVariables+1,nPoints).';
        V = temp(:,2:end);
    elseif numel(values) >= nVariables*nPoints
        V = reshape(values(1:nVariables*nPoints),nVariables,nPoints).';
    else
        error('ASCII real RAW contains fewer values than expected.');
    end

end

end
