close all
clear all

%Replace log files with the new logs you generated below are the original
%fname_gps='logs/2023-05-03_17_16_58_vehicleOut.txt';
%fname_power="logs/2023-05-03_17_16_58_power_log.txt";
%fname_quality="logs/2023-05-03_17_16_58_quality_log.txt";
fname_gps='logs/2025-11-04_13_00_00_vehicleOut.txt';
fname_power="logs/2025-11-04_13_00_00_power_log.txt";
fname_quality="logs/2025-11-04_13_00_00_quality_log.txt";


Qthreshold=70;

%Location of the transmitter (LW1)
%       "Latitude": 35.727451,
%       "Longitude": -78.695974,
origin_y=35.727451;
origin_x=-78.695974;

[timestamp_gps, timestamp_gps_for_csv, GPSx, GPSy, GPSz] = process_csv_GPS(fname_gps);
[timestamp_power1, mpower1, mquality, timestamp_power_for_csv1] = process_txt_CS(fname_power,fname_quality);

%Discard the measurements with a quality 
%lower than the threshold
validquality=[];
for i=1:length(mpower1)
    if mquality(i)>Qthreshold
        validquality=[validquality i];
    end
end

timestamp_power=timestamp_power1(validquality);
timestamp_power_for_csv=timestamp_power_for_csv1(validquality,:);
mpower=mpower1(validquality);

%Find location of the measurements
for i=1:length(timestamp_power)
    if timestamp_power(i)<timestamp_gps(1)
        mX(i,1)=GPSx(1);
        mY(i,1)=GPSy(1);
        mZ(i,1)=GPSz(1);
    elseif timestamp_power(i)>timestamp_gps(end)
        mX(i,1)=GPSx(end);
        mY(i,1)=GPSy(end);
        mZ(i,1)=GPSz(end);
    else
        mX(i,1)=interp1(timestamp_gps,GPSx,timestamp_power(i));
        mY(i,1)=interp1(timestamp_gps,GPSy,timestamp_power(i));
        mZ(i,1)=interp1(timestamp_gps,GPSz,timestamp_power(i));

    end
end

%Remove measurements before GPS started and after GPS ended
validindex=find((timestamp_power<timestamp_gps(end)) + (timestamp_power>timestamp_gps(1))-1);
mX=mX(validindex);
mY=mY(validindex);
mZ=mZ(validindex);
timestamp_power=timestamp_power(validindex);
timestamp_power_for_csv=timestamp_power_for_csv(validindex,:);
mpower=mpower(validindex);

figure(1)
hold on
plot((timestamp_gps-timestamp_gps(1)),GPSz,'x')
xlabel('time (s)')
ylabel('Altitude (m)')
title('GPS points')


figure(2)
hold on
plot((timestamp_power-timestamp_gps(1)),mZ,'x')
xlabel('time (s)')
ylabel('Altitude (m)')
title('measurement points')

for i=1:length(timestamp_power)
    mdistance(i,1)=sqrt((mX(i)-origin_x)^2 + (mY(i)-origin_y)^2)* 1.113195e5;
end

figure(3)
hold on
grid on
plot(mdistance,mpower,'x')
xlabel('distance (m)')
ylabel('Power (dB)')

figure(4)
clf
hold on
grid on
yyaxis left
plot((timestamp_power-timestamp_gps(1)),mdistance,'x')
xlabel('time (s)')
ylabel('distance(m)')
yyaxis right
plot((timestamp_power-timestamp_gps(1)),mpower,'x')
ylim([-20 50])
xlabel('time (s)')
ylabel('Power (dB)')


figure(5)
clf
hold on
grid on
scatter3(mX,mY,mZ,10,mpower)
scatter3(origin_x,origin_y,0,10,-60)
scatter3(origin_x,origin_y,0,100,-60)
scatter3(origin_x,origin_y,30,10,-60)
scatter3(origin_x,origin_y,30,100,-60)
x0=min(mX);x1=max(mX);y0=min(mY);y1=y0+(x1-x0);
xlim([x0 x1+0.00015   ]);
ylim([y0 y1]-(y1-y0)/2);
colormap(jet);
colorbar;
caxislim=[20 45];
caxis(caxislim)
xlabel('Longitude')
ylabel('Latitude')
zlabel('Altitude')
zlim([0 35]);
hcb=colorbar;
colorTitleHandle = get(hcb,'Title');
titleString = 'Power (dB)';
set(colorTitleHandle ,'String',titleString);

 
%Cretae input.csv for KML generation
csvfilename='input.csv';
if isfile(csvfilename)
    delete(csvfilename)
end

for i=1:length(timestamp_power)
    a=[num2str(i) ',' timestamp_power_for_csv(i,:) ',' num2str(mX(i),"%5.7f") ',' num2str(mY(i),"%5.7f") ',' num2str(mZ(i),"%5.7f") ',' num2str(mpower(i))];
    dlmwrite(csvfilename, a, 'delimiter', '', '-append');
end


if 0
    mkdir('figures')
    print('figures/altitudevstimeGPS','-f1', '-dpng')
    print('figures/altitudevstimeMEAS','-f2', '-dpng')
    print('figures/powervsdistance','-f3', '-dpng')
    print('figures/distance_powervstime','-f4', '-dpng')
    print('figures/scatter3D','-f5', '-dpng')
end

%save results_all.mat
