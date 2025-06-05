/*<info serverAlias="DBCUST-bodb_licensee" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_LicenseeMatchMonitoring_Ins]
    @LicenseeId		INT,
    @MatchID		INT,
    @BetType		SMALLINT=20,
    @LiveHomeScore	SMALLINT = NULL,
    @LiveAwayScore	SMALLINT = NULL,
    @LiveIndicator	BIT = 0,
	@Langkey		VARCHAR(20)	= 'en-US',
    @UserId			INT = 0,
    @IP				VARCHAR(20) = '',
    @ErrCode		INT = 0 OUTPUT,
    @ErrMsg			NVARCHAR(500) = NULL OUTPUT
AS
/*
    Created: 20250521@Tacy
    Task: LAP - Match Monitoring Center
    DB: DBCUST-bodb_licensee
    
    Revisions:
        - 20250521@Tacy: Create SP [RedmineID: #227673]

    Param's Explanation:
        @LiveHomeScore: Current home team score for live matches
        @LiveAwayScore: Current away team score for live matches
        @LiveIndicator: Flag indicating if match is live (1) or not (0)
*/
BEGIN
    SET NOCOUNT ON;    
	DECLARE @startRun DATETIME, @endRun DATETIME, @duration INT
    DECLARE @ActionID INT = 4001
    DECLARE @logSpData NVARCHAR(MAX)
    
	SET @startRun = GETDATE()
    
    BEGIN TRY
        -- Validate inputs        
		EXEC [dbo].[Lrf_LicenseeMatchMonitoring_Check]
            @LicenseeId = @LicenseeId,
            @MatchID = @MatchID,
            @BetType = @BetType,
            @LiveHomeScore = @LiveHomeScore,
            @LiveAwayScore = @LiveAwayScore,
            @LiveIndicator = @LiveIndicator,
            @Langkey = @Langkey,
			@ErrCode = @ErrCode OUTPUT,
            @ErrMsg = @ErrMsg OUTPUT

        IF @ErrCode <> 0
            RETURN @ErrCode

        DECLARE @MonitoringID INT

        INSERT INTO [dbo].[LicenseeMatchMonitoring]
        (
            LicenseeId,
            MatchID,
            BetType,
            LiveIndicator,
            LiveHomeScore,
            LiveAwayScore
        )
        VALUES
        (
            @LicenseeId,
            @MatchID,
            @BetType,
            @LiveIndicator,
            @LiveHomeScore,
            @LiveAwayScore
        )        
		
		SET @MonitoringID = SCOPE_IDENTITY()

    END TRY    
	BEGIN CATCH        
        SET @ErrMsg = ERROR_MESSAGE()
        SET @ErrCode = ERROR_NUMBER()
        RETURN
    END CATCH

	SET @endRun = GETDATE()
	SET @duration = DATEDIFF(millisecond, @startRun, @endRun)

	SET @logSpData = (
						SELECT 
							@MonitoringID AS MonitoringID,
							@LicenseeId AS LicenseeId,
							@MatchID AS MatchID,
							@BetType AS BetType,
							@LiveIndicator AS LiveIndicator,
							@LiveHomeScore AS LiveHomeScore,
							@LiveAwayScore AS LiveAwayScore
						FOR XML RAW ('r'), ROOT('Root')
					)
	
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.Lrf_WriteLog_UserLog_LicenseeSetting 
			@UserId = @UserID,
			@IP = @IP,
			@LicenseeID = @LicenseeID,
			@SPName = 'Lrf_LicenseeMatchMonitoring_Ins',
			@ActionId = @ActionID,
			@Duration = @Duration,
			@Data = @logSpData
	END TRY
	BEGIN CATCH
		EXEC bodb_CustomerLog.dbo.Lrf_WriteLog_UserLog_LicenseeSetting
			@UserId = @UserID,
			@IP = @IP,
			@LicenseeID = @LicenseeID,
			@SPName = 'Lrf_LicenseeMatchMonitoring_Ins',
			@ActionId = @ActionID,
			@Duration = @Duration,
			@Data = @logSpData
	END CATCH
END
GO
