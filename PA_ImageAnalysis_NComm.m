%% Start fresh
close all % Close all figures
clear     % Delete all variables
clc       % Delete all messages

%% Select folder and find the files
Path     = 'Put_your_path_here'; % path to file
BaseDir = [uigetdir(Path) '\'];
FileList = dir(fullfile(BaseDir,'*avi'));

%% Main loop = run over each file
for FileNum = 1:length(FileList)
    
    %% read the video file
    FileName = FileList(FileNum).name;
    V        = VideoReader([BaseDir FileName]); % Create the Video Object
    FrmNum   = 2;                               % Start from frame of interest (e.g. 2)
    MaxNumFrms = 256;                           
    if hasFrame(V)
        Frm = readFrame(V);  % here we read the first frame independently
    else
        disp('No frames were detected');
        return % quit the program
    end
    
    %% Preallocate memory
    VidSize = size(Frm);  % Get the frame size
    Vol = zeros(VidSize(1),VidSize(2),MaxNumFrms,3,'uint8'); % generate a volume of zeros
    Vol(:,:,1,:) = Frm; % Overwrite the first frame
    
    %% A loop to read every frame
    while hasFrame(V)                     % If the video object has more unread frames
        Vol(:,:,FrmNum,:) = readFrame(V); % Read the frame
        FrmNum            = FrmNum + 1;   % Move to the next frame
    end
    
    Vol (:,:,FrmNum:end,:) = []; % delete all empty frames
    VolSize = size(Vol);         % get the size of the actual video
    disp(['The video has ' num2str(VolSize(3)) ' Frames']);
    
    %% Find the binding ultrasound rectangle
    BW = logical((Vol(:,:,1,1) == Vol(:,:,1,2)) .* (Vol(:,:,1,2) ~= Vol(:,:,1,3)));  % Filter out only the yellow parts
    CornerSize = 30; CHS = ceil(CornerSize/2);                                       % Define a corner size for a hit & miss test
    Corner = -1*ones(CornerSize); Corner(:,1) = 1; Corner(1,:) = 1; Corner(1,1) = 0; % Generate the corner template
    UL_ind = bwhitmiss(BW,Corner);          UL_ind(1:CHS,1:CHS) = 0;                 % Hit & miss test for the upper left corner
    BR_ind = bwhitmiss(BW,rot90(Corner,2)); BR_ind(end-CHS:end,end-CHS:end) = 0;     % Hit & miss test for the bottom right corner
    
    % Find the upper left (UL) and bottom right (BR) columns and rows
    [UL_Col,UL_Row] = find(UL_ind,1); [BR_Col,BR_Row] = find(BR_ind,1);
    UL_Col = UL_Col - CHS; UL_Row = UL_Row - CHS + 1;
    BR_Col = BR_Col + CHS; BR_Row = BR_Row + CHS + 1;
    
    % Now to find the PA shift
    Dist_left = UL_Row-find(sum(Vol(UL_Col:BR_Col,1:UL_Row,1,1))==0,1,'last');
    Dist_right= find(sum(Vol(UL_Col:BR_Col,BR_Row+1:BR_Row+500,1,1))==0,1,'first'); % for our images PA is shifted 500 pixels to the right
    PA_shift = Dist_left+Dist_right+BR_Row-UL_Row;
    
    % Show the image just to make sure we got it right
    figure(1), imshow(squeeze(Vol(:,:,1,:))), hold on
    plot([UL_Row,UL_Row,BR_Row,BR_Row,UL_Row],[UL_Col,BR_Col,BR_Col,UL_Col,UL_Col],'LineWidth',2,'Color','green');
    plot([UL_Row,UL_Row,BR_Row,BR_Row,UL_Row]+PA_shift,[UL_Col,BR_Col,BR_Col,UL_Col,UL_Col],'LineWidth',2,'Color','red');
    
    %% Read the data frame by frame and put it in US_vol/ PA_vol
    kmax = size(Vol,3);
    US_vol = zeros(BR_Col-UL_Col-3,BR_Row-UL_Row-2,kmax);
    PA_vol = US_vol;
    
    % Cropping
    for k=1:kmax
        US_vol(:,:,k) = Vol(UL_Col+2:BR_Col-2,UL_Row+2:BR_Row-1,k,1);
        PA_vol(:,:,k) = Vol(UL_Col+2:BR_Col-2,(UL_Row+2:BR_Row-1)+PA_shift,k,1);
    end
    
    % PA figure and saving of the image
    figure, H_PA = vol3d('CData',PA_vol,'texture','3D');
    colormap hot;
    set(gca,'Color','k');
    title('PA');
    axis square;
    alphamap('rampup'); alphamap('decrease'); alphamap('decrease'); colorbar;
    view(0,-90);set(gca,'Color','k');
    saveas(gcf,[BaseDir 'Analyzed 3D videos\' FileName(1:end-4) '_PA_3D'],'tiff');
    
    % US figure and saving of the image
    figure, H_US = vol3d('CData',US_vol,'texture','3D');
    colormap gray;
    set(gca,'Color','k');
    title('US');
    axis square;
    alphamap('rampup'); alphamap('decrease'); alphamap('decrease'); alphamap('decrease'); alphamap('decrease'); alphamap('decrease'); alphamap('decrease');colorbar;
    view(3);
    
    % MIP PA
    figure, imagesc(max(PA_vol,[],3)); colormap hot; title('PA - Maximal Intensity Projection'); axis square;
    saveas(gcf,[BaseDir 'Analyzed 3D videos\' FileName(1:end-4) '_PA_MIP'],'tiff');
    
    % MIP US
    figure, imagesc(max(US_vol,[],3)); colormap gray; title('US - Maximal Intensity Projection'); axis square;
    saveas(gcf,[BaseDir 'Analyzed 3D videos\' FileName(1:end-4) '_US_MIP'],'tiff');
    
    % SIP PA
    figure, imagesc(sum(PA_vol,3)); colormap hot; title('PA - Sum Intensity Projection'); axis square;
    saveas(gcf,[BaseDir 'Analyzed 3D videos\' FileName(1:end-4) '_PA_SUM'],'tiff');
end