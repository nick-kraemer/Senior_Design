function [timestamp, time_stamp_for_csv, GPSx, GPSy, GPSz] = process_csv_GPS(fname)
%PROCESS_CSV_GPS  Parse vehicleOut-style GPS CSV log.
%
% Expected line formats:
%   (old) 1,-78.6740031,35.7717933,11.163,0.522,2021-06-01 16:33:24.646836,3,7
%   (new) 1,-122.6737098,38.3411063,38.9,2026-02-02 13:43:14.485533,07,1
%
% Outputs:
%   timestamp         : POSIX time (seconds since 1970, double), unique & sorted
%   time_stamp_for_csv: char matrix of timestamp strings as in file
%   GPSx, GPSy, GPSz  : longitude, latitude, altitude (double), matched to timestamp

    %------------------------------
    % Detect format (7 or 8 columns)
    %------------------------------
    fid = fopen(fname, 'r');
    if fid == -1
        error('process_csv_GPS:FileOpenFailed', 'Could not open file: %s', fname);
    end

    firstLine = fgetl(fid);
    if ~ischar(firstLine)
        fclose(fid);
        error('process_csv_GPS:EmptyFile', 'File appears to be empty: %s', fname);
    end

    nCommas = numel(strfind(firstLine, ','));
    frewind(fid);

    % Decide format string and which column is the timestamp
    switch nCommas
        case 7
            % 8 columns per line (old format with extra numeric before timestamp)
            % 1, lon, lat, alt, val, timestamp, field7, field8
            fmt     = '%f%f%f%f%f%s%f%f';
            tsIndex = 6;
        case 6
            % 7 columns per line (new format: no extra numeric before timestamp)
            % 1, lon, lat, alt, timestamp, field6, field7
            fmt     = '%f%f%f%f%s%f%f';
            tsIndex = 5;
        otherwise
            fclose(fid);
            error('process_csv_GPS:UnknownFormat', ...
                  'Unexpected number of commas (%d) in %s', nCommas, fname);
    end

    %------------------------------
    % Read the whole file
    %------------------------------
    C = textscan(fid, fmt, 'Delimiter', ',', 'HeaderLines', 0);
    fclose(fid);

    if isempty(C{1})
        error('process_csv_GPS:NoData', 'No data rows found in %s', fname);
    end

    % Column mapping (common to both formats):
    % C{1} = index (ignored)
    % C{2} = lon
    % C{3} = lat
    % C{4} = alt
    % C{tsIndex} = timestamp string
    lon    = C{2};
    lat    = C{3};
    alt    = C{4};
    tstr   = C{tsIndex};  % cell array of timestamp strings

    %------------------------------
    % Parse timestamps (with microseconds)
    %------------------------------
    % Example: '2026-02-02 13:43:14.485533'
    t = datetime(tstr, ...
        'InputFormat', 'yyyy-MM-dd HH:mm:ss.SSSSSS', ...
        'Format',      'yyyy-MM-dd HH:mm:ss.SSSSSS');

    timestamp = posixtime(t);

    %------------------------------
    % Enforce uniqueness & sort for interp1
    %------------------------------
    [timestampSorted, idxSort] = sort(timestamp);
    lon = lon(idxSort);
    lat = lat(idxSort);
    alt = alt(idxSort);
    tstr = tstr(idxSort);

    [timestampUnique, idxU] = unique(timestampSorted, 'stable');
    lon  = lon(idxU);
    lat  = lat(idxU);
    alt  = alt(idxU);
    tstr = tstr(idxU);

    timestamp = timestampUnique;

    %------------------------------
    % Outputs
    %------------------------------
    GPSx = lon;
    GPSy = lat;
    GPSz = alt;

    % time_stamp_for_csv as a char matrix (like your original code)
    time_stamp_for_csv = char(tstr);
end
