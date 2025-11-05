function [timestamp,mpower,mquality,timestamp_for_csv] = process_txt_CS(fname_power,fname_quality)
x = textread (fname_power,'%s','delimiter','\n');
y = textread (fname_quality,'%s','delimiter','\n');
%txt file typical data format
%[2022-10-27 17:30:38.712761] 0000000      -17.517574       -17.17565      -17.023443      -19.742756

N1=length(x);
N2=length(y);

cnt=0;
for i=1:min(N1,N2)-1
    stri=cell2mat(x(i));
    if length(findstr(stri,'*'))==0
        xsplit=strsplit(stri);
        ysplit=strsplit(cell2mat(y(i)));
        if str2num(xsplit{3})== str2num(ysplit{3})
            cnt=cnt+1
            str_ts= stri(strfind(stri,'[')+1:strfind(stri,']')-1);
            timestamp_for_csv(cnt,:)=str_ts;
            t(cnt,1)=datetime(str_ts(1:end-7),'Format','u-MM-d HH:mm:ss');
            %seconds since 1970
            %timestamp(cnt,1)=mktime(t(cnt));
            timestamp(cnt,1)=posixtime(t(cnt));
            %add the milliseconds separately
            timestamp(cnt,1)=timestamp(cnt,1)+str2num(['0.' str_ts(end-5:end)]);
            mpower(cnt,1)=str2num(xsplit{4});
            mquality(cnt,1)=str2num(ysplit{4});
        end
    end
end


