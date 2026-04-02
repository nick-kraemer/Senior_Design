function [timestamp, mpower, timestamp_for_csv] = process_txt_CS(fname_power)
x = textread (fname_power,'%s','delimiter','\n');
%txt file typical data format
%[2022-10-27 17:30:38.712761] 0000000      -17.517574       -17.17565      -17.023443      -19.742756

N1 = length(x);
cnt = 0;

for i = 1:N1-1
    stri = cell2mat(x(i));
    % skip lines with '*' (errors)
    if length(findstr(stri,'*')) == 0
        xsplit = strsplit(stri);

        cnt = cnt + 1;
        % timestamp inside [ ... ]
        str_ts = stri(strfind(stri,'[')+1 : strfind(stri,']')-1);
        timestamp_for_csv(cnt,:) = str_ts;

        t(cnt,1) = datetime(str_ts, 'InputFormat','yyyy-MM-dd HH:mm:ss', ...
                             'Format','yyyy-MM-dd HH:mm:ss');

        timestamp(cnt,1) = posixtime(t(cnt));
       % timestamp(cnt,1) = timestamp(cnt,1) + str2num(['0.' str_ts(end-5:end)]);

        % power value (3rd numeric field after timestamp/count)
        mpower(cnt,1) = str2num(xsplit{4});
    end
end
